import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/course_attendance.dart';
import '../services/attendance_service.dart';

class AttendanceOverviewController {
  final AttendanceService _attendanceService = AttendanceService();

  Future<List<CourseAttendance>> fetchCourseAttendancePercentage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return [];

      final userId = user!.email!.toLowerCase();

      // Ensure past absences are marked before calculation
      await _attendanceService.markPastAbsences(userId);

      // Get all attendance records for this user
      final attendanceSnap = await FirebaseFirestore.instance
          .collection('Attendance')
          .where('email', isEqualTo: userId)
          .get();

      if (attendanceSnap.docs.isEmpty) return [];

      // Group by course and calculate attendance percentage
      final courseMap = <String, CourseAttendance>{};

      for (var doc in attendanceSnap.docs) {
        final data = doc.data();
        final courseName = data['courseName'] ?? 'Unknown Course';
        final status = data['status'] ?? 'absent';

        if (!courseMap.containsKey(courseName)) {
          courseMap[courseName] = CourseAttendance(
            courseName: courseName,
            totalSessions: 0,
            presentSessions: 0,
          );
        }

        courseMap[courseName]!.totalSessions++;
        if (status == 'present') {
          courseMap[courseName]!.presentSessions++;
        }
      }

      // Convert to list and calculate percentage
      // We use a baseline of 14 sessions (standard semester) to ensure the percentage
      // starts at 100% and decreases gradually, rather than starting at 0%.
      // If total recorded sessions > 14, we use the actual total.
      final courseList = courseMap.values.map((course) {
        final int baselineTotal = 7;
        final int effectiveTotal = course.totalSessions > baselineTotal
            ? course.totalSessions
            : baselineTotal;

        final int absentSessions =
            course.totalSessions - course.presentSessions;

        // Calculate percentage lost based on absences
        final double percentageLost = effectiveTotal > 0
            ? (absentSessions / effectiveTotal * 100)
            : 0.0;

        final double percentage = 100.0 - percentageLost;

        return CourseAttendance(
          courseName: course.courseName,
          totalSessions: course.totalSessions,
          presentSessions: course.presentSessions,
          percentage: double.parse(percentage.toStringAsFixed(1)),
        );
      }).toList();

      // Sort by percentage descending
      courseList.sort(
        (a, b) => (b.percentage ?? 0).compareTo(a.percentage ?? 0),
      );

      return courseList;
    } catch (e) {
      debugPrint('Error fetching course attendance: $e');
      return [];
    }
  }

  Color getColorForPercentage(double percentage) {
    if (percentage >= 80) {
      return Colors.green;
    } else if (percentage >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
