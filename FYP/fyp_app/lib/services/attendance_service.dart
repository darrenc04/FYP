import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final Map<String, DateTime> _lastCheckMap = {};
  static const Duration _checkCooldown = Duration(minutes: 5);

  /// Mark absent for past sessions where no attendance was recorded.
  /// This should be called when the student logs in or views the attendance page.
  Future<void> markPastAbsences(String userEmail) async {
    // 1. Check rate limit
    if (_lastCheckMap.containsKey(userEmail)) {
      final lastCheck = _lastCheckMap[userEmail]!;
      if (DateTime.now().difference(lastCheck) < _checkCooldown) {
        debugPrint('Skipping markPastAbsences (rate limited)');
        return;
      }
    }

    try {
      final userDoc = await _firestore.collection('Users').doc(userEmail).get();
      if (!userDoc.exists) return;

      final List<String> sessionIds = List<String>.from(
        userDoc['sessionsId'] ?? [],
      );
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);

      for (String sessionId in sessionIds) {
        // Fetch session metadata
        final sessionDoc = await _firestore
            .collection('Sessions')
            .doc(sessionId)
            .get();
        if (!sessionDoc.exists) continue;

        // Default to looking back 60 days
        DateTime startDate = today.subtract(const Duration(days: 60));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);

        // Iterate from startDate up to yesterday
        for (
          DateTime date = startDate;
          date.isBefore(today);
          date = date.add(const Duration(days: 1))
        ) {
          final String dateStr = DateFormat('yyyy-MM-dd').format(date);

          // 1. Check if a class actually existed this day
          final sessionInfoRef = _firestore
              .collection('Sessions')
              .doc(sessionId)
              .collection(dateStr)
              .doc('session_info');

          final sessionInfoSnap = await sessionInfoRef.get();
          if (!sessionInfoSnap.exists) continue;
          if (sessionInfoSnap.data()?['isCancelled'] == true) continue;

          // 2. Efficiently check for existing records (and duplicates)
          // We fetch ALL matches to detect duplicates
          final attendanceQuery = await _firestore
              .collection('Attendance')
              .where('email', isEqualTo: userEmail)
              .where('sessionId', isEqualTo: sessionId)
              .where('sessionDate', isEqualTo: dateStr)
              .get();

          // DEDUPLICATION LOGIC
          if (attendanceQuery.docs.isNotEmpty) {
            // If we have more than 1 record, it's a duplicate situation
            if (attendanceQuery.docs.length > 1) {
              // Keep the first one, delete the rest
              // Sort checks could go here, but for 'absent' any one is fine.
              // We prioritize keeping 'present' if mixed (unlikely for specific date match absent logic)

              // If any is 'present', keep that and delete all 'absent'
              bool hasPresent = attendanceQuery.docs.any(
                (d) => d['status'] == 'present',
              );

              for (var doc in attendanceQuery.docs) {
                if (hasPresent && doc['status'] == 'absent') {
                  await doc.reference.delete();
                  debugPrint('Deleted duplicate absent record: ${doc.id}');
                } else if (!hasPresent &&
                    attendanceQuery.docs.indexOf(doc) > 0) {
                  // Keep index 0, delete others
                  await doc.reference.delete();
                  debugPrint('Deleted duplicate absent record: ${doc.id}');
                }
              }
            }
            continue; // Record exists (or we cleaned up to 1), so skip creation
          }

          // Legacy Fallback Check (for records without sessionDate)
          final startOfDay = date;
          final endOfDay = date.add(const Duration(days: 1));

          final legacyAttendanceQuery = await _firestore
              .collection('Attendance')
              .where('email', isEqualTo: userEmail)
              .where('sessionId', isEqualTo: sessionId)
              // optimizing legacy check is hard without composite index on markedAt,
              // so we rely on client-side filtering of limited set if possible,
              // or just simple query
              .get();

          bool hasLegacyRecord = false;
          for (var doc in legacyAttendanceQuery.docs) {
            final markedAt = (doc['markedAt'] as Timestamp?)?.toDate();
            if (markedAt != null &&
                markedAt.isAfter(startOfDay) &&
                markedAt.isBefore(endOfDay)) {
              hasLegacyRecord = true;
              break;
            }
          }
          if (hasLegacyRecord) continue;

          // 3. Mark as absent using DETERMINISTIC ID to prevent future duplicates
          // ID format: sessionId_dateStr_email
          // We replace special chars in email to be safe, though firestore is usually lenient.
          // actually standard email is fine.
          final String docId = '${sessionId}_${dateStr}_${userEmail}';

          await _firestore.collection('Attendance').doc(docId).set({
            'email': userEmail,
            'sessionId': sessionId,
            'courseName': sessionDoc.data()?['sessionsName'] ?? 'Unknown',
            'status': 'absent',
            'sessionDate': dateStr,
            'markedAt': FieldValue.serverTimestamp(),
            'verificationMethod': 'auto_absent',
            'isAutoGenerated': true,
          });

          debugPrint(
            'Auto-marked absent (idempotent) for $userEmail in $sessionId on $dateStr',
          );
        }
      }

      // Update cache
      _lastCheckMap[userEmail] = DateTime.now();
    } catch (e) {
      debugPrint('Error marking past absences: $e');
    }
  }

  /// Mark attendance manually (e.g. by teacher)
  Future<void> markManualAttendance({
    required String sessionId,
    required String sessionName,
    required String studentEmail,
    required DateTime sessionDate,
    required String status,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(sessionDate);
    final startOfDay = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Check existing record
    final query = await _firestore
        .collection('Attendance')
        .where('sessionId', isEqualTo: sessionId)
        .where('email', isEqualTo: studentEmail)
        .get();

    DocumentReference? docRef;

    // Find the specific daily record
    for (var doc in query.docs) {
      // Check sessionDate first
      if (doc.data().containsKey('sessionDate')) {
        if (doc['sessionDate'] == dateStr) {
          docRef = doc.reference;
          break;
        }
      } else {
        // Legacy: Check markedAt time
        final markedAt = (doc['markedAt'] as Timestamp?)?.toDate();
        if (markedAt != null &&
            markedAt.isAfter(startOfDay) &&
            markedAt.isBefore(endOfDay)) {
          docRef = doc.reference;
          break;
        }
      }
    }

    final data = {
      'sessionId': sessionId,
      'courseName': sessionName,
      'email': studentEmail,
      'status': status,
      'sessionDate': dateStr,
      'markedAt': FieldValue.serverTimestamp(),
      'verificationMethod': 'manual',
    };

    if (docRef != null) {
      await docRef.update(data);
    } else {
      await _firestore.collection('Attendance').add(data);
    }
  }
}
