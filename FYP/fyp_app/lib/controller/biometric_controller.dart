import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../model/biometric_settings.dart';

class BiometricController {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // API Configuration
  static const String DEEPFACE_API_URL = 'http://10.119.150.15:5000';

  Future<BiometricSettings> loadBiometricSettings({
    bool isMockMode = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return BiometricSettings(
          isEnabled: false,
          isFaceVerified: false,
          isFingerprintVerified: false,
          hasBiometricCapability: false,
          availableBiometrics: [],
        );
      }

      // Check device biometric capabilities
      bool canCheckBiometrics = false;
      bool isDeviceSupported = false;
      List<BiometricType> availableBiometrics = [];

      try {
        canCheckBiometrics = await _localAuth.canCheckBiometrics;
        isDeviceSupported = await _localAuth.isDeviceSupported();
      } catch (e) {
        debugPrint('Biometric check failed: $e');
      }

      if (canCheckBiometrics && isDeviceSupported) {
        try {
          availableBiometrics = await _localAuth.getAvailableBiometrics();
          debugPrint('Available biometrics: $availableBiometrics');
        } catch (e) {
          debugPrint('Error getting biometrics: $e');
        }
      } else {
        debugPrint('Biometrics not available or device not supported');
      }

      // Load user's biometric preference from Firestore
      final docId = user.email!.toLowerCase();
      final doc = await _firestore.collection('Users').doc(docId).get();

      if (doc.exists) {
        final data = doc.data();
        final biometricValue = data?['biometric'] ?? '';
        final faceVerified = data?['faceVerified'] ?? false;
        final fingerprintVerified = data?['fingerprintVerified'] ?? false;

        return BiometricSettings(
          isEnabled: biometricValue.isNotEmpty,
          isFaceVerified: faceVerified,
          isFingerprintVerified: fingerprintVerified,
          hasBiometricCapability: availableBiometrics.isNotEmpty,
          availableBiometrics: availableBiometrics,
        );
      }

      return BiometricSettings(
        isEnabled: false,
        isFaceVerified: false,
        isFingerprintVerified: false,
        hasBiometricCapability: availableBiometrics.isNotEmpty,
        availableBiometrics: availableBiometrics,
      );
    } catch (e) {
      debugPrint('Error loading biometric settings: $e');
      return BiometricSettings(
        isEnabled: false,
        isFaceVerified: false,
        isFingerprintVerified: false,
        hasBiometricCapability: false,
        availableBiometrics: [],
      );
    }
  }

  Future<void> toggleBiometric(
    bool value, {
    required bool hasBiometricCapability,
    required bool isMockMode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    String biometricValue = '';
    if (value) {
      if (!isMockMode && !hasBiometricCapability) {
        throw Exception(
          'Biometric authentication is not available on this device',
        );
      }
      biometricValue = 'enabled';
    } else {
      // When disabling, also reset face and fingerprint verification
      final docId = user.email!.toLowerCase();
      await _firestore.collection('Users').doc(docId).update({
        'faceVerified': false,
        'fingerprintVerified': false,
      });
    }

    // Update Firestore
    final docId = user.email!.toLowerCase();
    await _firestore.collection('Users').doc(docId).update({
      'biometric': biometricValue,
    });
  }

  Future<Map<String, dynamic>> verifyFingerprint({
    required bool isMockMode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final userId = user.email!.toLowerCase();

    // Mock mode: simulate fingerprint verification
    if (isMockMode) {
      await Future.delayed(const Duration(seconds: 1));

      final docId = userId;
      final userDoc = await _firestore.collection('Users').doc(docId).get();
      final isFirstRegistration =
          !(userDoc.data()?['fingerprintVerified'] ?? false);

      if (isFirstRegistration) {
        await _firestore.collection('Users').doc(docId).update({
          'fingerprintVerified': true,
          'fingerprintRegistrationDate': FieldValue.serverTimestamp(),
        });
        return {
          'success': true,
          'isRegistration': true,
          'message': 'Fingerprint registered successfully! (Mock Mode)',
        };
      } else {
        return {
          'success': true,
          'isRegistration': false,
          'message': 'Fingerprint verified! (Mock Mode)',
        };
      }
    }

    // Real mode: use local_auth for fingerprint verification
    final isAuthenticated = await _localAuth.authenticate(
      localizedReason: 'Verify your fingerprint',
      options: const AuthenticationOptions(
        stickyAuth: false,
        biometricOnly: true,
      ),
    );

    if (isAuthenticated) {
      final docId = userId;
      final userDoc = await _firestore.collection('Users').doc(docId).get();
      final isFirstRegistration =
          !(userDoc.data()?['fingerprintVerified'] ?? false);

      if (isFirstRegistration) {
        await _firestore.collection('Users').doc(docId).update({
          'fingerprintVerified': true,
          'fingerprintRegistrationDate': FieldValue.serverTimestamp(),
        });
        return {
          'success': true,
          'isRegistration': true,
          'message': 'Fingerprint registered successfully!',
        };
      } else {
        return {
          'success': true,
          'isRegistration': false,
          'message': 'Fingerprint verified successfully!',
        };
      }
    } else {
      throw Exception('Fingerprint verification failed');
    }
  }

  Future<Map<String, dynamic>> verifyFaceIdentity({
    required bool isMockMode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final userId = user.email!.toLowerCase();

    // Mock mode: simulate face verification
    if (isMockMode) {
      await Future.delayed(const Duration(seconds: 2));

      final docId = userId;
      final userDoc = await _firestore.collection('Users').doc(docId).get();
      final isFirstRegistration = !(userDoc.data()?['faceVerified'] ?? false);

      if (isFirstRegistration) {
        await _firestore.collection('Users').doc(docId).update({
          'faceVerified': true,
          'faceRegistrationDate': FieldValue.serverTimestamp(),
        });
        return {
          'success': true,
          'isRegistration': true,
          'message': 'Face registered successfully! (Mock Mode)',
        };
      } else {
        return {
          'success': true,
          'isRegistration': false,
          'message': 'Face verified! Confidence: 98.50% (Mock Mode)',
        };
      }
    }

    // Real mode: Check DeepFace API availability
    final healthResponse = await http
        .get(Uri.parse('$DEEPFACE_API_URL/health'))
        .timeout(const Duration(seconds: 5));

    if (healthResponse.statusCode != 200) {
      throw Exception(
        'DeepFace server is not responding. Is it running on http://localhost:5000?',
      );
    }

    // Capture video from camera
    final XFile? video = await _imagePicker.pickVideo(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxDuration: const Duration(seconds: 10),
    );

    if (video == null) {
      throw Exception('No video captured');
    }

    // Check if first registration
    final docId = userId;
    final userDoc = await _firestore.collection('Users').doc(docId).get();
    final isFirstRegistration = !(userDoc.data()?['faceVerified'] ?? false);

    if (isFirstRegistration) {
      return await registerFaceVideo(userId, video);
    } else {
      throw Exception(
        'Face already registered. Please use a different account.',
      );
    }
  }

  Future<Map<String, dynamic>> registerFaceVideo(
    String userId,
    XFile video,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$DEEPFACE_API_URL/register-face-video'),
    );

    request.fields['user_id'] = userId;
    request.files.add(await http.MultipartFile.fromPath('video', video.path));

    final response = await request.send().timeout(const Duration(seconds: 60));
    final responseBody = await response.stream.bytesToString();

    debugPrint('Register video response status: ${response.statusCode}');
    debugPrint('Register video response body: $responseBody');

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(responseBody);
      final framesUsed = jsonData['frames_used'] as int? ?? 0;

      // Update Firestore
      final docId = userId;
      await _firestore.collection('Users').doc(docId).update({
        'faceVerified': true,
        'faceRegistrationDate': FieldValue.serverTimestamp(),
        'registrationMethod': 'video_multi_frame',
        'registrationFramesUsed': framesUsed,
      });

      return {
        'success': true,
        'isRegistration': true,
        'message':
            'Face registered successfully!\nUsed $framesUsed frames for better accuracy.',
        'framesUsed': framesUsed,
      };
    } else {
      throw Exception(
        'Registration failed: ${response.statusCode}. $responseBody',
      );
    }
  }
}
