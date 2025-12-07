class FingerprintVerificationState {
  final bool isRegistered;
  final bool isVerifying;
  final bool attendanceMarked;
  final String? statusMessage;

  FingerprintVerificationState({
    required this.isRegistered,
    this.isVerifying = false,
    this.attendanceMarked = false,
    this.statusMessage,
  });

  bool get canVerify => isRegistered && !isVerifying && !attendanceMarked;

  String get registrationStatus {
    if (!isRegistered) {
      return 'Fingerprint Not Registered';
    }
    return 'Fingerprint Registered';
  }

  String get registrationDescription {
    if (!isRegistered) {
      return 'Please register your fingerprint first in Device Settings.';
    }
    return 'Ready for fingerprint verification';
  }
}
