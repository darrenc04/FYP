/// Model to represent session statistics in teacher dashboard
class SessionStat {
  final String name;
  final String code;
  final double percentage;
  final int present;
  final int totalStudents;
  final String sessionId;
  final bool isCancelled;

  SessionStat({
    required this.name,
    required this.code,
    required this.percentage,
    required this.present,
    required this.totalStudents,
    required this.sessionId,
    required this.isCancelled,
  });

  factory SessionStat.fromMap(Map<String, dynamic> map) {
    return SessionStat(
      name: map['name'] as String,
      code: map['code'] as String,
      percentage: (map['percentage'] as num).toDouble(),
      present: map['present'] as int,
      totalStudents: map['totalStudents'] as int,
      sessionId: map['sessionId'] as String,
      isCancelled: map['isCancelled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'percentage': percentage,
      'present': present,
      'totalStudents': totalStudents,
      'sessionId': sessionId,
      'isCancelled': isCancelled,
    };
  }
}

/// Model to represent overall dashboard data
class TeacherDashboardData {
  final int totalSessions;
  final List<SessionStat> sessionStats;
  final bool isHolidayDate;

  TeacherDashboardData({
    required this.totalSessions,
    required this.sessionStats,
    required this.isHolidayDate,
  });

  TeacherDashboardData copyWith({
    int? totalSessions,
    List<SessionStat>? sessionStats,
    bool? isHolidayDate,
  }) {
    return TeacherDashboardData(
      totalSessions: totalSessions ?? this.totalSessions,
      sessionStats: sessionStats ?? this.sessionStats,
      isHolidayDate: isHolidayDate ?? this.isHolidayDate,
    );
  }
}

/// Model to represent student attendance data
class StudentAttendanceData {
  final String id;
  final String name;
  final String idNumber;
  final String email;
  final String? status;
  final String? attendanceDocId;
  final String? revokedBy;

  StudentAttendanceData({
    required this.id,
    required this.name,
    required this.idNumber,
    required this.email,
    this.status,
    this.attendanceDocId,
    this.revokedBy,
  });

  bool get isPresent => status == 'present';
  bool get isRevoked => revokedBy == 'teacher';

  factory StudentAttendanceData.fromMap(Map<String, dynamic> map) {
    return StudentAttendanceData(
      id: map['id'] as String,
      name: map['name'] as String,
      idNumber: map['idNumber'] as String,
      email: map['email'] as String,
      status: map['status'] as String?,
      attendanceDocId: map['attendanceDocId'] as String?,
      revokedBy: map['revokedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'idNumber': idNumber,
      'email': email,
      'status': status,
      'attendanceDocId': attendanceDocId,
      'revokedBy': revokedBy,
    };
  }
}
