class PasswordResetResult {
  final bool success;
  final String? errorMessage;

  PasswordResetResult({required this.success, this.errorMessage});

  factory PasswordResetResult.success() {
    return PasswordResetResult(success: true);
  }

  factory PasswordResetResult.failure(String error) {
    return PasswordResetResult(success: false, errorMessage: error);
  }

  bool get hasError => !success && errorMessage != null;
}
