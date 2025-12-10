import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../model/session_data.dart';

class TimetableController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Assuming Semester Start Date is Monday, Nov 17, 2025
  final DateTime semesterStartDate = DateTime(2025, 11, 17);

  /// Get the start and end dates for a specific week (1-indexed)
  /// Returns a list of 7 dates (Mon-Sun)
  List<DateTime> getDatesForWeek(int weekIndex) {
    // weekIndex is 1-7
    final weekStartDate = semesterStartDate.add(
      Duration(days: (weekIndex - 1) * 7),
    );
    return List.generate(
      7,
      (index) => weekStartDate.add(Duration(days: index)),
    );
  }

  /// Fetch sessions for a specific week number (1-7)
  Future<Map<String, List<SessionData>>> fetchSessionsForWeek(
    int weekIndex,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user?.email == null) return {};

      final docId = user!.email!.toLowerCase();
      final userDoc = await _firestore.collection('Users').doc(docId).get();

      if (!userDoc.exists) return {};

      final sessionIds = List<String>.from(userDoc['sessionsId'] ?? []);
      final datesStr = getDatesForWeek(
        weekIndex,
      ).map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();

      Map<String, List<SessionData>> weekSessions = {};

      // Initialize empty lists for each date to ensure all days are shown
      for (var date in datesStr) {
        weekSessions[date] = [];
      }

      for (String sessionId in sessionIds) {
        for (String dateStr in datesStr) {
          try {
            final sessionSubDoc = await _firestore
                .collection('Sessions')
                .doc(sessionId)
                .collection(dateStr)
                .doc('session_info')
                .get();

            if (sessionSubDoc.exists) {
              final sessionData = sessionSubDoc.data() as Map<String, dynamic>;

              // We don't strictly need attendance status for timetable view,
              // but we can parse basic info.
              // If needed, we can add attendance logic here later.

              final session = SessionData.fromMap({
                ...sessionData,
                'isCancelled': sessionData['isCancelled'] ?? false,
              }, sessionId);

              weekSessions[dateStr]?.add(session);
            }
          } catch (e) {
            debugPrint('Error fetching session $sessionId for $dateStr: $e');
          }
        }
      }

      // Sort sessions by start time for each day
      weekSessions.forEach((date, sessions) {
        sessions.sort((a, b) {
          if (a.startTime == null || b.startTime == null) return 0;
          return a.startTime!.compareTo(b.startTime!);
        });
      });

      return weekSessions;
    } catch (e) {
      debugPrint('Error fetching week $weekIndex sessions: $e');
      return {};
    }
  }
}
