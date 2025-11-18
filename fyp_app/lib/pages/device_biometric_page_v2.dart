import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeviceBiometricPageV2 extends StatefulWidget {
  const DeviceBiometricPageV2({Key? key}) : super(key: key);

  @override
  State<DeviceBiometricPageV2> createState() => _DeviceBiometricPageV2State();
}

class _DeviceBiometricPageV2State extends State<DeviceBiometricPageV2> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // API Configuration
  static const String DEEPFACE_API_URL = 'http://10.0.2.2:5000'; // Android emulator localhost
  // For physical device, use: 'http://<your-machine-ip>:5000'

  bool _isEnabled = false;
  bool _isFaceVerified = false;
  bool _isFingerprintVerified = false;
  List<BiometricType> _availableBiometrics = [];
  bool _isLoading = true;
  bool _hasBiometricCapability = false;
  bool _isVerifyingFace = false;
  bool _isVerifyingFingerprint = false;
  bool _isMockMode = true; // Set to false for production; true for testing without biometrics

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initBiometric() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check device biometric capabilities
      bool canCheckBiometrics = false;
      bool isDeviceSupported = false;

      try {
        canCheckBiometrics = await _localAuth.canCheckBiometrics;
        isDeviceSupported = await _localAuth.isDeviceSupported();
      } catch (e) {
        print('Biometric check failed: $e');
      }

      if (canCheckBiometrics && isDeviceSupported) {
        try {
          _availableBiometrics = await _localAuth.getAvailableBiometrics();
          print('Available biometrics: $_availableBiometrics');
          _hasBiometricCapability = _availableBiometrics.isNotEmpty;
        } catch (e) {
          print('Error getting biometrics: $e');
        }
      } else {
        print('Biometrics not available or device not supported');
      }

      // Load user's biometric preference from Firestore
      final docId = user.email!.toLowerCase();
      final doc = await _firestore.collection('Users').doc(docId).get();

      if (doc.exists) {
        final data = doc.data();
        final biometricValue = data?['biometric'] ?? '';
        final faceVerified = data?['faceVerified'] ?? false;
        final fingerprintVerified = data?['fingerprintVerified'] ?? false;

        if (mounted) {
          setState(() {
            _isEnabled = biometricValue.isNotEmpty;
            _isFaceVerified = faceVerified;
            _isFingerprintVerified = fingerprintVerified;
          });
        }
      }
    } catch (e) {
      print('Error in _initBiometric: $e');
      if (mounted) {
        _showErrorSnackBar('Error loading biometric settings: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      String biometricValue = '';
      if (value) {
        // In mock mode, allow biometric even without device capability
        if (!_isMockMode && !_hasBiometricCapability) {
          _showErrorSnackBar(
            'Biometric authentication is not available on this device',
          );
          return;
        }

        biometricValue = 'enabled';
      } else {
        // When disabling, also reset face and fingerprint verification
        final docId = user.email!.toLowerCase();
        await _firestore.collection('Users').doc(docId).update({
          'faceVerified': false,
          'fingerprintVerified': false,
        });
        setState(() {
          _isFaceVerified = false;
          _isFingerprintVerified = false;
        });
      }

      // Update Firestore
      final docId = user.email!.toLowerCase();
      await _firestore.collection('Users').doc(docId).update({
        'biometric': biometricValue,
      });

      setState(() {
        _isEnabled = value;
      });

      _showSuccessSnackBar(
        value
            ? 'Biometric enabled. Please verify your face identity.'
            : 'Biometric disabled',
      );
    } catch (e) {
      print('Error in _toggleBiometric: $e');
      _showErrorSnackBar('Error updating biometric: $e');
    }
  }

  Future<void> _verifyFingerprint() async {
    try {
      setState(() => _isVerifyingFingerprint = true);

      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        setState(() => _isVerifyingFingerprint = false);
        return;
      }

      final userId = user.email!.toLowerCase();

      // Mock mode: simulate fingerprint verification
      if (_isMockMode) {
        _showInfoSnackBar('Mock Mode: Simulating fingerprint verification...');
        await Future.delayed(const Duration(seconds: 1));

        // Check if this is first registration
        final docId = userId;
        final userDoc = await _firestore.collection('Users').doc(docId).get();
        final isFirstRegistration =
            !(userDoc.data()?['fingerprintVerified'] ?? false);

        if (isFirstRegistration) {
          // Mock registration
          await _firestore.collection('Users').doc(docId).update({
            'fingerprintVerified': true,
            'fingerprintRegistrationDate': FieldValue.serverTimestamp(),
          });
          setState(() {
            _isFingerprintVerified = true;
            _isVerifyingFingerprint = false;
          });
          _showSuccessSnackBar('Fingerprint registered successfully! (Mock Mode)');
        } else {
          // Mock verification
          setState(() => _isVerifyingFingerprint = false);
          _showSuccessSnackBar('Fingerprint verified! (Mock Mode)');
        }
        return;
      }

      // Real mode: use local_auth for fingerprint verification
      try {
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
            setState(() {
              _isFingerprintVerified = true;
              _isVerifyingFingerprint = false;
            });
            _showSuccessSnackBar('Fingerprint registered successfully!');
          } else {
            setState(() => _isVerifyingFingerprint = false);
            _showSuccessSnackBar('Fingerprint verified successfully!');
          }
        } else {
          _showErrorSnackBar('Fingerprint verification failed');
          setState(() => _isVerifyingFingerprint = false);
        }
      } catch (e) {
        _showErrorSnackBar('Error verifying fingerprint: $e');
        setState(() => _isVerifyingFingerprint = false);
      }
    } catch (e) {
      print('Error in _verifyFingerprint: $e');
      _showErrorSnackBar('Error: $e');
      if (mounted) setState(() => _isVerifyingFingerprint = false);
    }
  }

  Future<void> _verifyFaceIdentity() async {
    try {
      setState(() => _isVerifyingFace = true);

      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        setState(() => _isVerifyingFace = false);
        return;
      }

      final userId = user.email!.toLowerCase();

      // Mock mode: simulate face verification without actual DeepFace server
      if (_isMockMode) {
        _showInfoSnackBar('Mock Mode: Simulating face verification...');
        await Future.delayed(const Duration(seconds: 2));

        // Check if this is first registration
        final docId = userId;
        final userDoc = await _firestore.collection('Users').doc(docId).get();
        final isFirstRegistration =
            !(userDoc.data()?['faceVerified'] ?? false);

        if (isFirstRegistration) {
          // Mock registration
          await _firestore.collection('Users').doc(docId).update({
            'faceVerified': true,
            'faceRegistrationDate': FieldValue.serverTimestamp(),
          });
          setState(() {
            _isFaceVerified = true;
            _isVerifyingFace = false;
          });
          _showSuccessSnackBar('Face registered successfully! (Mock Mode)');
        } else {
          // Mock verification
          setState(() => _isVerifyingFace = false);
          _showSuccessSnackBar('Face verified! Confidence: 98.50% (Mock Mode)');
        }

        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // Real mode: use DeepFace backend
      // Check if DeepFace API is available
      try {
        final healthResponse = await http.get(
          Uri.parse('$DEEPFACE_API_URL/health'),
        ).timeout(const Duration(seconds: 5));

        if (healthResponse.statusCode != 200) {
          _showErrorSnackBar(
              'DeepFace server is not responding. Is it running on http://localhost:5000?');
          setState(() => _isVerifyingFace = false);
          return;
        }
      } catch (e) {
        _showErrorSnackBar(
            'Cannot reach DeepFace server. Please ensure it\'s running.\nAddress: $DEEPFACE_API_URL\nError: $e');
        setState(() => _isVerifyingFace = false);
        return;
      }

      // Capture image from camera
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image == null) {
        _showErrorSnackBar('No image captured');
        setState(() => _isVerifyingFace = false);
        return;
      }

      // Check if this is first registration or verification
      final docId = userId;
      final userDoc = await _firestore.collection('Users').doc(docId).get();
      final isFirstRegistration = !(userDoc.data()?['faceVerified'] ?? false);

      if (isFirstRegistration) {
        // Register face
        await _registerFace(userId, image);
      } else {
        // Verify face
        await _verifyFaceAgainstRegistered(userId, image);
      }
    } catch (e) {
      print('Error in _verifyFaceIdentity: $e');
      _showErrorSnackBar('Error during face verification: $e');
      if (mounted) setState(() => _isVerifyingFace = false);
    }
  }

  Future<void> _registerFace(String userId, XFile image) async {
    try {
      _showInfoSnackBar('Registering your face...');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$DEEPFACE_API_URL/register-face'),
      );

      request.fields['user_id'] = userId;
      request.files.add(
        await http.MultipartFile.fromPath('image', image.path),
      );

      final response =
          await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      print('Register response status: ${response.statusCode}');
      print('Register response body: $responseBody');

      if (response.statusCode == 200) {
        // Update Firestore
        final docId = userId;
        await _firestore.collection('Users').doc(docId).update({
          'faceVerified': true,
          'faceRegistrationDate': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            _isFaceVerified = true;
            _isVerifyingFace = false;
          });
        }

        _showSuccessSnackBar('Face registered successfully!');
      } else {
        _showErrorSnackBar(
            'Registration failed: ${response.statusCode}. $responseBody');
        if (mounted) setState(() => _isVerifyingFace = false);
      }
    } catch (e) {
      print('Error in _registerFace: $e');
      _showErrorSnackBar('Registration error: $e');
      if (mounted) setState(() => _isVerifyingFace = false);
    }
  }

  Future<void> _verifyFaceAgainstRegistered(
      String userId, XFile image) async {
    try {
      _showInfoSnackBar('Verifying your face...');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$DEEPFACE_API_URL/verify-face'),
      );

      request.fields['user_id'] = userId;
      request.files.add(
        await http.MultipartFile.fromPath('image', image.path),
      );

      final response =
          await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      print('Verify response status: ${response.statusCode}');
      print('Verify response body: $responseBody');

      if (response.statusCode == 200) {
        // Parse response
        try {
          final jsonData = jsonDecode(responseBody);
          final isMatch = jsonData['is_match'] ?? false;
          final confidence = jsonData['confidence'] ?? 0.0;

          if (isMatch) {
            _showSuccessSnackBar(
                'Face verified! Confidence: ${confidence.toStringAsFixed(2)}%');
          } else {
            _showErrorSnackBar(
                'Face does not match. Confidence: ${confidence.toStringAsFixed(2)}%');
          }
        } catch (e) {
          _showErrorSnackBar('Error parsing response: $e');
        }
      } else if (response.statusCode == 404) {
        _showErrorSnackBar('User face not found. Please register first.');
      } else {
        _showErrorSnackBar(
            'Verification failed: ${response.statusCode}. $responseBody');
      }

      if (mounted) setState(() => _isVerifyingFace = false);
    } catch (e) {
      print('Error in _verifyFaceAgainstRegistered: $e');
      _showErrorSnackBar('Verification error: $e');
      if (mounted) setState(() => _isVerifyingFace = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Device Biometric (DeepFace)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Enable/Disable Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Device Biometric',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        Switch(
                          value: _isEnabled,
                          onChanged: _toggleBiometric,
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Verify Face Button (shown when enabled but not verified)
                  if (_isEnabled && !_isFaceVerified) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.face_retouching_natural,
                                  color: Colors.orange.shade700,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Face Identity Required',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Register your face for attendance',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isVerifyingFace ? null : _verifyFaceIdentity,
                              icon: _isVerifyingFace
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt),
                              label: Text(_isVerifyingFace
                                  ? 'Registering...'
                                  : 'Register Face'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Verify Fingerprint Button (shown when enabled but not verified)
                  if (_isEnabled && !_isFingerprintVerified) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.fingerprint,
                                  color: Colors.blue.shade700,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Fingerprint Registration',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Register your fingerprint for attendance',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isVerifyingFingerprint ? null : _verifyFingerprint,
                              icon: _isVerifyingFingerprint
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.fingerprint),
                              label: Text(_isVerifyingFingerprint
                                  ? 'Registering...'
                                  : 'Register Fingerprint'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Status Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isEnabled
                          ? (_isFaceVerified
                              ? Colors.green.shade50
                              : Colors.orange.shade50)
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isEnabled
                            ? (_isFaceVerified
                                ? Colors.green
                                : Colors.orange)
                            : Colors.orange,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isEnabled
                              ? (_isFaceVerified
                                  ? Icons.check_circle
                                  : Icons.warning_amber)
                              : Icons.info_outline,
                          color: _isEnabled
                              ? (_isFaceVerified
                                  ? Colors.green
                                  : Colors.orange)
                              : Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEnabled
                                    ? (_isFaceVerified && _isFingerprintVerified
                                        ? 'Biometric Active (Face & Fingerprint)'
                                        : _isFaceVerified
                                            ? 'Face Verified - Fingerprint Pending'
                                            : _isFingerprintVerified
                                                ? 'Fingerprint Verified - Face Pending'
                                                : 'Registration Pending')
                                    : 'Biometric Disabled',
                                style: TextStyle(
                                  color: _isEnabled
                                      ? (_isFaceVerified
                                          ? Colors.green
                                          : Colors.orange)
                                      : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isEnabled
                                    ? (_isFaceVerified && _isFingerprintVerified
                                        ? 'Face & Fingerprint verified. Ready for attendance.'
                                        : 'Please complete all biometric registrations')
                                    : 'Biometric verification is disabled',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isEnabled
                                      ? (_isFaceVerified
                                          ? Colors.green.shade800
                                          : Colors.orange.shade800)
                                      : Colors.orange.shade800,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Info Box
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: _isMockMode ? Colors.purple : Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isMockMode ? 'Mock Mode Testing' : 'Using DeepFace',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isMockMode)
                          _buildBulletPoint(
                            '⚠️ MOCK MODE: Biometric capability simulation for testing without real biometrics.',
                            color: Colors.purple.shade700,
                          ),
                        if (_isMockMode)
                          _buildBulletPoint(
                            'Face registration and verification are simulated. Set _isMockMode = false to use real DeepFace.',
                            color: Colors.purple.shade700,
                          ),
                        if (!_isMockMode) ...[
                          _buildBulletPoint(
                            'Enable Device Biometric to register your face.',
                          ),
                          _buildBulletPoint(
                            'Your face will be verified using DeepFace technology.',
                            color: Colors.blue.shade700,
                          ),
                        ],
                        _buildBulletPoint(
                          'Tap "Register Face" to capture and register your face image.',
                        ),
                        _buildBulletPoint(
                          'On subsequent logins, your face will be automatically verified.',
                        ),
                        _buildBulletPoint(
                          'Ensure good lighting and clear face visibility for best results.',
                        ),
                        if (!_isMockMode)
                          _buildBulletPoint(
                            'Make sure DeepFace backend server is running on your machine.',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBulletPoint(String text, {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 16, color: color)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: color, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
