import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../model/login_result.dart';

class LoginController {
  final AuthService _authService = AuthService();

  bool isValidInput(String email, String password) {
    return email.isNotEmpty && password.isNotEmpty;
  }

  bool isAdminCredentials(String email, String password) {
    return email == 'admin@gmail.com' && password == 'admin123';
  }

  Future<LoginResult> signInWithEmail(String email, String password) async {
    try {
      final user = await _authService.signInWithEmail(
        email.trim(),
        password.trim(),
      );

      if (user != null) {
        return LoginResult.success(user);
      } else {
        return LoginResult.failure('Login failed');
      }
    } on FirebaseAuthException catch (e) {
      return LoginResult.failure(e.message ?? 'An error occurred during login');
    } catch (e) {
      return LoginResult.failure(e.toString());
    }
  }

  Future<LoginResult> signInWithGoogle() async {
    try {
      final user = await _authService.signInWithGoogle();

      if (user != null) {
        return LoginResult.success(user);
      } else {
        return LoginResult.failure('Google sign-in failed');
      }
    } on MissingPluginException catch (_) {
      return LoginResult.failure(
        'Google Sign-In is not available on this platform or the plugin was not registered. Try a full restart: flutter clean; flutter pub get; flutter run.',
      );
    } catch (e) {
      return LoginResult.failure(e.toString());
    }
  }
}
