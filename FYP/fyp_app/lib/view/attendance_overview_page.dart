import 'package:flutter/material.dart';
import '../model/course_attendance.dart';
import '../controller/attendance_overview_controller.dart';
import '../component/course_attendance_card.dart';
import 'attendance_history_page.dart';

class AttendanceOverviewPage extends StatefulWidget {
  const AttendanceOverviewPage({super.key});

  @override
  State<AttendanceOverviewPage> createState() => _AttendanceOverviewPageState();
}

class _AttendanceOverviewPageState extends State<AttendanceOverviewPage> {
  final AttendanceOverviewController _controller =
      AttendanceOverviewController();
  late Future<List<CourseAttendance>> _courseAttendanceList;

  @override
  void initState() {
    super.initState();
    _courseAttendanceList = _controller.fetchCourseAttendancePercentage();
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
              final color = _controller.getColorForPercentage(percentage);

              return CourseAttendanceCard(
                course: course,
                color: color,
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
              );
            },
          );
        },
      ),
    );
  }
}
