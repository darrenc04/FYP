import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final String sessionId;
  final String courseName;
  final Timestamp? markedAt;
  final String status;
  final String verificationMethod;
  final Timestamp? startTime;
  final Timestamp? endTime;
  final String sessionType;
  final String? sessionDate;

  AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.courseName,
    this.markedAt,
    required this.status,
    required this.verificationMethod,
    this.startTime,
    this.endTime,
    required this.sessionType,
    this.sessionDate,
  });

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> data) {
    return AttendanceRecord(
      id: id,
      sessionId: data['sessionId'] ?? '',
      courseName: data['sessionName'] ?? 'Unknown Course',
      markedAt: data['markedAt'] as Timestamp?,
      status: data['status'] ?? 'absent',
      verificationMethod: data['verificationMethod'] ?? 'unknown',
      startTime: data['startTime'] as Timestamp?,
      endTime: data['endTime'] as Timestamp?,
      sessionType: data['sessionType'] ?? '',
      sessionDate: data['sessionDate'] as String?,
    );
  }

  bool get isAbsent => status == 'absent';
}
