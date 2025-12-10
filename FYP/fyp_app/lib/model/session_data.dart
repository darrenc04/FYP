import 'package:cloud_firestore/cloud_firestore.dart';

class SessionData {
  final String id;
  final String sessionName;
  final String sessionType;
  final String? lecturerName;
  final String physicalLocation;
  final Timestamp? startTime;
  final Timestamp? endTime;
  final String? courseCode;

  // Student-specific fields
  final bool attendanceMarked;
  final bool attendanceRevoked;
  final String revocationReason;

  // Common fields
  final bool isCancelled;

  SessionData({
    required this.id,
    required this.sessionName,
    required this.sessionType,
    this.lecturerName,
    required this.physicalLocation,
    this.startTime,
    this.endTime,
    this.courseCode,
    this.attendanceMarked = false,
    this.attendanceRevoked = false,
    this.revocationReason = '',
    this.isCancelled = false,
  });

  factory SessionData.fromMap(Map<String, dynamic> map, String sessionId) {
    return SessionData(
      id: sessionId,
      sessionName: map['sessionsName'] ?? 'Unknown Session',
      sessionType: map['sessionsType'] ?? 'Class',
      lecturerName: map['lecturerName'],
      physicalLocation: map['physicalLocation'] ?? 'Unknown Location',
      startTime: map['start_time'] as Timestamp?,
      endTime: map['end_time'] as Timestamp?,
      courseCode: map['courseCode'],
      attendanceMarked: map['attendanceMarked'] ?? false,
      attendanceRevoked: map['attendanceRevoked'] ?? false,
      revocationReason: map['revocationReason'] ?? '',
      isCancelled: map['isCancelled'] ?? false,
    );
  }

  String get sessionTypeInitial {
    if (sessionType.toLowerCase().contains('lecture')) {
      return 'L';
    } else if (sessionType.toLowerCase().contains('tutorial')) {
      return 'T';
    }
    return 'P';
  }

  bool get isLecture => sessionType.toLowerCase().contains('lecture');
  bool get isTutorialOrPractical =>
      sessionType.toLowerCase().contains('tutorial') ||
      sessionType.toLowerCase().contains('practical');
}
