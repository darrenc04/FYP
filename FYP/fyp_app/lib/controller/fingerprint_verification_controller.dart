import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

class FingerprintVerificationController {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if user has registered fingerprint in Firestore
  Future<bool> checkFingerprintRegistration() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userId = user.email!.toLowerCase();
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      final isFingerprintVerified =
          userDoc.data()?['fingerprintVerified'] ?? false;

      return isFingerprintVerified;
    } catch (e) {
      debugPrint('Error checking fingerprint registration: $e');
      return false;
    }
  }

  /// Get available biometric methods on device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return [];
    }
  }

  /// Authenticate user with fingerprint
  Future<bool> authenticateWithFingerprint() async {
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your fingerprint to mark attendance',
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: true,
        ),
      );
      return isAuthenticated;
    } catch (e) {
      debugPrint('Error during fingerprint verification: $e');
      return false;
    }
  }

  /// Get current authenticated user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
