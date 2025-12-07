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
