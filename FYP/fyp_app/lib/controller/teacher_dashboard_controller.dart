import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../model/teacher_dashboard_data.dart';

/// Controller to handle teacher dashboard business logic
class TeacherDashboardController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Default public holidays list (as fallback)
  final Set<String> defaultPublicHolidays = {
    '2025-01-25', '2025-02-01', '2025-02-10', '2025-02-11', '2025-03-28',
    '2025-04-10', '2025-04-11', '2025-05-01', '2025-05-22', '2025-06-03',
    '2025-07-07', '2025-07-30', '2025-08-31', '2025-09-16', '2025-10-24',
    '2025-12-25', '2026-01-01', '2026-01-29', '2026-02-10', '2026-02-11',
    '2026-02-14', '2026-04-10', '2026-05-01', '2026-05-24', '2026-06-03',
    '2026-07-07', '2026-08-31', '2026-09-16', '2026-10-29', '2026-12-25',
    '2025-11-25', // testing
  };

  Set<String> _publicHolidays = {};

  TeacherDashboardController() {
    _publicHolidays = defaultPublicHolidays;
  }

  /// Check if a date is a public holiday
  bool isPublicHoliday(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    return _publicHolidays.contains(dateString);
  }

  /// Fetch public holidays from Calendarific API for Malaysia
  Future<Set<String>> loadPublicHolidays() async {
    try {
      final year = DateTime.now().year;
      final response = await _fetchHolidaysFromApi(year);
      if (response.isNotEmpty) {
        _publicHolidays = response.toSet();
        return _publicHolidays;
      }
    } catch (e) {
      print('Error loading public holidays: $e');
    }
    return _publicHolidays;
  }

  Future<List<String>> _fetchHolidaysFromApi(int year) async {
    try {
      const String apiKey = 'USE WHEN NEEDED';
      final url = Uri.parse(
        'https://calendarific.com/api/v2/holidays?api_key=$apiKey&country=MY&year=$year',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return [];
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> holidays = data['response']?['holidays'] ?? [];
        final List<String> holidayDates = [];
        for (var holiday in holidays) {
          final date = holiday['date']?['iso'] as String?;
          if (date != null && date.isNotEmpty) {
            holidayDates.add(date);
          }
        }
        return holidayDates;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch dashboard data for a specific date
  Future<TeacherDashboardData> fetchDashboardData(DateTime selectedDate) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return TeacherDashboardData(
          totalSessions: 0,
          sessionStats: [],
          isHolidayDate: false,
        );
      }

      final teacherEmail = user.email!.toLowerCase();

      final userDoc = await _firestore
          .collection('Users')
          .doc(teacherEmail)
          .get();

      if (!userDoc.exists) {
        return TeacherDashboardData(
          totalSessions: 0,
          sessionStats: [],
          isHolidayDate: false,
        );
      }

      // Check for holiday first
      bool isHoliday = isPublicHoliday(selectedDate);

      if (isHoliday) {
        return TeacherDashboardData(
          totalSessions: 0,
          sessionStats: [],
          isHolidayDate: true,
        );
      }

      // If not holiday, fetch sessions
      final sessionIds = List<String>.from(userDoc['sessionsId'] ?? []);
      List<SessionStat> sessionStats = [];

      for (String sessionId in sessionIds) {
        final sessionDoc = await _firestore
            .collection('Sessions')
            .doc(sessionId)
            .get();

        if (!sessionDoc.exists) continue;

        final sessionData = sessionDoc.data()!;

        // Check for specific session in subcollection
        final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
        final sessionSubDoc = await _firestore
            .collection('Sessions')
            .doc(sessionId)
            .collection(dateStr)
            .doc('session_info')
            .get();

        if (!sessionSubDoc.exists) continue;

        // Use subcollection data if available
        final subData = sessionSubDoc.data()!;
        bool isCancelled = subData['isCancelled'] == true;

        final sessionName = sessionData['sessionsName'] ?? 'Unknown';
        final courseCode = sessionData['courseCode'] ?? sessionId;

        final attendanceQuery = await _firestore
            .collection('Attendance')
            .where('sessionId', isEqualTo: sessionId)
            .get();

        final studentsQuery = await _firestore
            .collection('Users')
            .where('sessionsId', arrayContains: sessionId)
            .where('role', isEqualTo: 'student')
            .get();

        int totalStudents = studentsQuery.docs.length;

        final startOfDay = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
        final endOfDay = startOfDay.add(const Duration(days: 1));

        int present = attendanceQuery.docs.where((doc) {
          final data = doc.data();
          if (data.containsKey('sessionDate')) {
            return data['sessionDate'] == dateStr &&
                data['status'] == 'present';
          }
          // Legacy fallback
          final markedAt = (data['markedAt'] as Timestamp?)?.toDate();
          return markedAt != null &&
              markedAt.isAfter(startOfDay) &&
              markedAt.isBefore(endOfDay) &&
              data['status'] == 'present';
        }).length;

        double percentage = 0;
        if (totalStudents > 0) {
          percentage = (present / totalStudents) * 100;
        }

        sessionStats.add(
          SessionStat(
            name: sessionName,
            code: courseCode,
            percentage: percentage.clamp(0.0, 100.0),
            present: present,
            totalStudents: totalStudents,
            sessionId: sessionId,
            isCancelled: isCancelled,
          ),
        );
      }

      return TeacherDashboardData(
        totalSessions: sessionStats.length,
        sessionStats: sessionStats,
        isHolidayDate: false,
      );
    } catch (e) {
      print("Error fetching dashboard data: $e");
      return TeacherDashboardData(
        totalSessions: 0,
        sessionStats: [],
        isHolidayDate: false,
      );
    }
  }
}
