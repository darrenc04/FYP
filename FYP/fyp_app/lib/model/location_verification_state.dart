class LocationVerificationState {
  final bool verifying;
  final bool verified;
  final String? errorMessage;
  final double? distance;
  final String? courseName;

  LocationVerificationState({
    this.verifying = true,
    this.verified = false,
    this.errorMessage,
    this.distance,
    this.courseName,
  });

  LocationVerificationState copyWith({
    bool? verifying,
    bool? verified,
    String? errorMessage,
    double? distance,
    String? courseName,
  }) {
    return LocationVerificationState(
      verifying: verifying ?? this.verifying,
      verified: verified ?? this.verified,
      errorMessage: errorMessage ?? this.errorMessage,
      distance: distance ?? this.distance,
      courseName: courseName ?? this.courseName,
    );
  }

  bool get isSuccess => !verifying && verified;
  bool get isError => !verifying && !verified && errorMessage != null;
  bool get isVerifying => verifying;
}
