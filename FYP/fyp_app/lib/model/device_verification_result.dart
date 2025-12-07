class DeviceVerificationResult {
  final bool isVerified;
  final String? errorMessage;
  final bool shouldProceedToLocation;

  DeviceVerificationResult({
    required this.isVerified,
    this.errorMessage,
    this.shouldProceedToLocation = false,
  });

  bool get hasError => errorMessage != null;
}
