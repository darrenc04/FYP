class FaceVerificationResult {
  final bool success;
  final int blinksDetected;
  final double faceConfidence;
  final double blinkConfidence;
  final bool isLive;
  final String? error;

  FaceVerificationResult({
    required this.success,
    this.blinksDetected = 0,
    this.faceConfidence = 0.0,
    this.blinkConfidence = 0.0,
    this.isLive = false,
    this.error,
  });

  factory FaceVerificationResult.fromJson(Map<String, dynamic> json) {
    return FaceVerificationResult(
      success: json['success'] ?? false,
      blinksDetected: json['blinks_detected'] as int? ?? 0,
      faceConfidence: (json['face_confidence'] as num?)?.toDouble() ?? 0.0,
      blinkConfidence: (json['blink_confidence'] as num?)?.toDouble() ?? 0.0,
      isLive: json['is_live'] ?? false,
      error: json['error'],
    );
  }

  bool get isVerified =>
      success && isLive && blinksDetected >= 2 && faceConfidence >= 65.0;

  String get failureReason {
    if (!success) return error ?? 'Verification failed';

    List<String> reasons = [];
    if (faceConfidence < 65.0) {
      reasons.add(
        'Face does not match (${faceConfidence.toStringAsFixed(2)}% - need at least 65%)',
      );
    }
    if (blinksDetected < 2) {
      reasons.add('Need at least 2 blinks, detected: $blinksDetected');
    }
    if (!isLive) {
      reasons.add('No live face detected');
    }
    return reasons.isEmpty ? 'Verification failed' : reasons.join('. ');
  }

  String get successMessage =>
      'Face matched! Blinks: $blinksDetected, Confidence: ${faceConfidence.toStringAsFixed(2)}%';
}
