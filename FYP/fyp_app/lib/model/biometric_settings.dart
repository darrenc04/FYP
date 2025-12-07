class BiometricSettings {
  final bool isEnabled;
  final bool isFaceVerified;
  final bool isFingerprintVerified;
  final bool hasBiometricCapability;
  final List<dynamic> availableBiometrics;

  BiometricSettings({
    required this.isEnabled,
    required this.isFaceVerified,
    required this.isFingerprintVerified,
    required this.hasBiometricCapability,
    required this.availableBiometrics,
  });

  bool get isFullyVerified => isFaceVerified && isFingerprintVerified;
  bool get hasAnyVerification => isFaceVerified || isFingerprintVerified;

  String get statusMessage {
    if (!isEnabled) return 'Biometric Disabled';
    if (isFullyVerified) return 'Biometric Active (Face & Fingerprint)';
    if (isFaceVerified && !isFingerprintVerified)
      return 'Face Verified - Fingerprint Pending';
    if (!isFaceVerified && isFingerprintVerified)
      return 'Fingerprint Verified - Face Pending';
    return 'Registration Pending';
  }

  String get statusDescription {
    if (!isEnabled) return 'Biometric verification is disabled';
    if (isFullyVerified)
      return 'Face & Fingerprint verified. Ready for attendance.';
    return 'Please complete all biometric registrations';
  }
}
