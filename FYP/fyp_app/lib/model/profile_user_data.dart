/// Model to represent user profile data
class ProfileUserData {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String idNumber;
  final String address;
  final String? profilePicture;

  ProfileUserData({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.idNumber,
    required this.address,
    this.profilePicture,
  });

  /// Create ProfileUserData from Firestore document
  factory ProfileUserData.fromFirestore(
    Map<String, dynamic> data,
    String? userEmail,
  ) {
    return ProfileUserData(
      fullName: data['fullName'] ?? 'Not provided',
      email: data['email'] ?? userEmail ?? 'Not provided',
      phoneNumber: data['phoneNumber'] ?? 'Not provided',
      idNumber: data['idNumber'] ?? 'Not provided',
      address: data['address'] ?? 'Not provided',
      profilePicture: data['profilePicture'],
    );
  }

  /// Convert to map for Firestore updates
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'idNumber': idNumber,
      'address': address,
      'profilePicture': profilePicture,
    };
  }

  /// Create a copy with updated fields
  ProfileUserData copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? idNumber,
    String? address,
    String? profilePicture,
  }) {
    return ProfileUserData(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      idNumber: idNumber ?? this.idNumber,
      address: address ?? this.address,
      profilePicture: profilePicture ?? this.profilePicture,
    );
  }
}
