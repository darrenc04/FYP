import 'package:firebase_auth/firebase_auth.dart';

class LoginResult {
  final bool success;
  final User? user;
  final String? errorMessage;

  LoginResult({required this.success, this.user, this.errorMessage});

  factory LoginResult.success(User user) {
    return LoginResult(success: true, user: user);
  }

  factory LoginResult.failure(String message) {
    return LoginResult(success: false, errorMessage: message);
  }

  bool get hasError => !success && errorMessage != null;
}
