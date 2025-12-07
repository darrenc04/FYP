import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for ultrasonic detection state
class UltrasonicDetectionState {
  final bool isRecording;
  final bool isDetecting;
  final bool attendanceMarked;
  final String? detectionMessage;
  final double? dominantFrequency;
  final int targetFrequency;
  final bool loadingFrequency;

  UltrasonicDetectionState({
    this.isRecording = false,
    this.isDetecting = false,
    this.attendanceMarked = false,
    this.detectionMessage,
    this.dominantFrequency,
    this.targetFrequency = -1,
    this.loadingFrequency = true,
  });

  UltrasonicDetectionState copyWith({
    bool? isRecording,
    bool? isDetecting,
    bool? attendanceMarked,
    String? detectionMessage,
    double? dominantFrequency,
    int? targetFrequency,
    bool? loadingFrequency,
  }) {
    return UltrasonicDetectionState(
      isRecording: isRecording ?? this.isRecording,
      isDetecting: isDetecting ?? this.isDetecting,
      attendanceMarked: attendanceMarked ?? this.attendanceMarked,
      detectionMessage: detectionMessage ?? this.detectionMessage,
      dominantFrequency: dominantFrequency ?? this.dominantFrequency,
      targetFrequency: targetFrequency ?? this.targetFrequency,
      loadingFrequency: loadingFrequency ?? this.loadingFrequency,
    );
  }
}

/// Model for session frequency data
class SessionFrequencyData {
  final int targetFrequency;
  final Timestamp? frequencyGeneratedAt;

  SessionFrequencyData({
    required this.targetFrequency,
    this.frequencyGeneratedAt,
  });

  factory SessionFrequencyData.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) {
      return SessionFrequencyData(targetFrequency: -1);
    }

    final frequency = data['targetFrequency'] ?? -1;
    return SessionFrequencyData(
      targetFrequency: frequency is int
          ? frequency
          : (frequency as num).toInt(),
      frequencyGeneratedAt: data['frequencyGeneratedAt'] as Timestamp?,
    );
  }

  bool isFresh() {
    if (frequencyGeneratedAt == null) return false;
    final now = DateTime.now();
    final generatedTime = frequencyGeneratedAt!.toDate();
    // Allow up to 15 seconds delay (broadcasts every 7s)
    return now.difference(generatedTime).inSeconds < 15;
  }
}

/// Model for FFT analysis result
class FFTAnalysisResult {
  final double frequency;
  final double magnitude;
  final double noiseFloor;
  final double snr;
  final bool isValid;
  final String? rejectionReason;

  FFTAnalysisResult({
    required this.frequency,
    required this.magnitude,
    required this.noiseFloor,
    required this.snr,
    required this.isValid,
    this.rejectionReason,
  });
}
