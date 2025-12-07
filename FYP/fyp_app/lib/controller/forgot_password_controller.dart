import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../model/password_reset_result.dart';

class ForgotPasswordController {
  final AuthService _authService = AuthService();

  /// Validate email input
  bool isEmailValid(String email) {
    return email.trim().isNotEmpty;
  }

  /// Send password reset email
  Future<PasswordResetResult> sendPasswordResetEmail(String email) async {
    if (!isEmailValid(email)) {
      return PasswordResetResult.failure('Please enter your email');
    }

    try {
      await _authService.sendPasswordResetEmail(email.trim());
      return PasswordResetResult.success();
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth error: ${e.message}');
      return PasswordResetResult.failure(e.message ?? 'An error occurred');
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      return PasswordResetResult.failure(e.toString());
    }
  }
}
