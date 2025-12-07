class HomeUserData {
  final String name;
  final String role;
  final String? profilePicture;

  HomeUserData({required this.name, required this.role, this.profilePicture});

  bool get isTeacher => role.toLowerCase() == 'teacher';
  bool get isStudent => role.toLowerCase() == 'student';

  String get displayRole => isTeacher ? 'Teacher' : 'Student';
}
