import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../model/teacher_dashboard_data.dart';
import '../services/attendance_service.dart';

/// Controller to handle manual attendance operations
class ManualAttendanceController {
  final AttendanceService _attendanceService = AttendanceService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch students enrolled in a session with their attendance status
  Future<List<StudentAttendanceData>> fetchStudents(
    String sessionId,
    DateTime selectedDate,
  ) async {
    try {
      // 1. Fetch students enrolled in this session
      final studentsQuery = await _firestore
          .collection('Users')
          .where('sessionsId', arrayContains: sessionId)
          .where('role', isEqualTo: 'student')
          .get();

      // 2. Fetch attendance for the selected date
      final startOfDay = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final attendanceQuery = await _firestore
          .collection('Attendance')
          .where('sessionId', isEqualTo: sessionId)
          .get();

      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

      // Map student Email -> Attendance Doc
      Map<String, DocumentSnapshot> attendanceMap = {};
      for (var doc in attendanceQuery.docs) {
        final data = doc.data();

        bool isMatch = false;
        if (data.containsKey('sessionDate')) {
          if (data['sessionDate'] == dateStr) {
            isMatch = true;
          }
        } else {
          // Legacy fallback
          final markedAt = (data['markedAt'] as Timestamp?)?.toDate();
          if (markedAt != null &&
              markedAt.isAfter(startOfDay) &&
              markedAt.isBefore(endOfDay)) {
            isMatch = true;
          }
        }

        if (isMatch) {
          final email = data['email'] as String?;
          if (email != null) {
            attendanceMap[email.toLowerCase()] = doc;
          }
        }
      }

      List<StudentAttendanceData> students = [];

      for (var doc in studentsQuery.docs) {
        final data = doc.data();
        final email = (data['email'] as String?)?.toLowerCase() ?? '';

        String? status;
        String? attendanceDocId;
        String? revokedBy;

        if (attendanceMap.containsKey(email)) {
          final attendanceDoc = attendanceMap[email]!;
          final attendanceData = attendanceDoc.data() as Map<String, dynamic>?;
          status = attendanceData?['status'];
          attendanceDocId = attendanceDoc.id;
          revokedBy = attendanceData?['revokedBy'];
        }

        students.add(
          StudentAttendanceData(
            id: doc.id,
            name: data['fullName'] ?? 'Unknown',
            idNumber: data['idNumber'] ?? '',
            email: email,
            status: status,
            attendanceDocId: attendanceDocId,
            revokedBy: revokedBy,
          ),
        );
      }

      return students;
    } catch (e) {
      print("Error fetching students: $e");
      return [];
    }
  }

  /// Mark a student as present
  Future<void> markPresent({
    required String sessionId,
    required String sessionName,
    required String studentEmail,
    required DateTime sessionDate,
  }) async {
    await _attendanceService.markManualAttendance(
      sessionId: sessionId,
      sessionName: sessionName,
      studentEmail: studentEmail,
      sessionDate: sessionDate,
      status: 'present',
    );
  }

  /// Revoke attendance for a student
  Future<void> revokeAttendance({
    required String attendanceDocId,
    required String reason,
  }) async {
    await _firestore.collection('Attendance').doc(attendanceDocId).update({
      'status': 'absent',
      'revocationReason': reason,
      'revokedAt': FieldValue.serverTimestamp(),
      'revokedBy': 'teacher',
    });
  }

  /// Filter students by search query
  List<StudentAttendanceData> filterStudents(
    List<StudentAttendanceData> students,
    String query,
  ) {
    if (query.isEmpty) {
      return students;
    }

    final lowerQuery = query.toLowerCase().trim();
    return students.where((student) {
      final name = student.name.toLowerCase();
      final idNumber = student.idNumber.toLowerCase();
      return name.contains(lowerQuery) || idNumber.contains(lowerQuery);
    }).toList();
  }
}
