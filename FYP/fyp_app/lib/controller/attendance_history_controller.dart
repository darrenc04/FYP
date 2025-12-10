import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/attendance_record.dart';

class AttendanceHistoryController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<AttendanceRecord>> fetchAttendanceHistory(
    String filterCourse,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user?.email == null) return [];

      final userId = user!.email!.toLowerCase();
      final attendanceSnap = await _firestore
          .collection('Attendance')
          .where('email', isEqualTo: userId)
          .orderBy('markedAt', descending: true)
          .get();

      List<AttendanceRecord> records = [];

      for (var doc in attendanceSnap.docs) {
        final data = doc.data();
        final courseName = data['courseName'] ?? 'Unknown Course';
        final sessionId = data['sessionId'] ?? '';
        final sessionType = data['sessionType'] ?? 'Unknown Session Type';
        final startTime = data['startTime'] as Timestamp?;
        final endTime = data['endTime'] as Timestamp?;

        // Apply filter
        if (filterCourse != 'All' && courseName != filterCourse) {
          continue;
        }

        records.add(
          AttendanceRecord(
            id: doc.id,
            sessionId: sessionId,
            courseName: courseName,
            markedAt: data['markedAt'] as Timestamp?,
            status: data['status'] ?? 'absent',
            verificationMethod: data['verificationMethod'] ?? 'unknown',
            startTime: startTime,
            endTime: endTime,
            sessionType: sessionType,
            sessionDate: data['sessionDate'],
          ),
        );
      }

      return records;
    } catch (e) {
      debugPrint('Error fetching attendance history: $e');
      return [];
    }
  }
}
