import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'attendance_history_page.dart';

class AttendanceOverviewPage extends StatefulWidget {
  const AttendanceOverviewPage({super.key});

  @override
  State<AttendanceOverviewPage> createState() =>
      _AttendanceOverviewPageState();
}

class _AttendanceOverviewPageState extends State<AttendanceOverviewPage> {
  late Future<List<CourseAttendance>> _courseAttendanceList;

  @override
  void initState() {
    super.initState();
    _courseAttendanceList = _fetchCourseAttendancePercentage();
  }

  Future<List<CourseAttendance>> _fetchCourseAttendancePercentage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return [];

      final userId = user!.email!.toLowerCase();

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
      final courseList = courseMap.values.map((course) {
        final percentage = course.totalSessions > 0
            ? (course.presentSessions / course.totalSessions * 100).toStringAsFixed(1)
            : '0.0';
        return CourseAttendance(
          courseName: course.courseName,
          totalSessions: course.totalSessions,
          presentSessions: course.presentSessions,
          percentage: double.parse(percentage),
        );
      }).toList();

      // Sort by percentage descending
      courseList.sort((a, b) => (b.percentage ?? 0).compareTo(a.percentage ?? 0));

      return courseList;
    } catch (e) {
      debugPrint('Error fetching course attendance: $e');
      return [];
    }
  }

  Color _getColorForPercentage(double percentage) {
    if (percentage >= 80) {
      return Colors.green;
    } else if (percentage >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3D4A4F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3D4A4F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Attendance Overview',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: FutureBuilder<List<CourseAttendance>>(
        future: _courseAttendanceList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          final courses = snapshot.data ?? [];

          if (courses.isEmpty) {
            return const Center(
              child: Text(
                'No attendance records found',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              final percentage = course.percentage ?? 0;
              final color = _getColorForPercentage(percentage);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AttendanceHistoryPage(
                        selectedCourse: course.courseName,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.courseName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${course.presentSessions}/${course.totalSessions} sessions attended',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Circular percentage indicator
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withOpacity(0.1),
                          border: Border.all(
                            color: color,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${percentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CourseAttendance {
  final String courseName;
  int totalSessions;
  int presentSessions;
  final double? percentage;

  CourseAttendance({
    required this.courseName,
    required this.totalSessions,
    required this.presentSessions,
    this.percentage,
  });
}
