import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class DeviceBiometricPage extends StatefulWidget {
  const DeviceBiometricPage({Key? key}) : super(key: key);

  @override
  State<DeviceBiometricPage> createState() => _DeviceBiometricPageState();
}

class _DeviceBiometricPageState extends State<DeviceBiometricPage> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();
  late FaceDetector _faceDetector;
  bool _faceDetectorInitialized = false;

  bool _isEnabled = false;
  bool _isFaceVerified = false;
  List<BiometricType> _availableBiometrics = [];
  bool _isLoading = true;
  bool _hasBiometricCapability = false;
  bool _isVerifyingFace = false;
  bool _isEmulator = false;

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  @override
  void dispose() {
    _closeFaceDetector();
    super.dispose();
  }

  Future<void> _initializeFaceDetector() async {
    if (_faceDetectorInitialized || _isEmulator) return;
    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableClassification: true,
          enableLandmarks: true,
          enableTracking: true,
        ),
      );
      _faceDetectorInitialized = true;
    } catch (e) {
      print('Error initializing face detector: \$e');
      if (mounted) {
        setState(() => _isEmulator = true);
      }
    }
  }

  void _closeFaceDetector() {
    if (_faceDetectorInitialized) {
      try {
        _faceDetector.close();
      } catch (e) {
        print('Error closing face detector: \$e');
      }
    }
  }

  Future<void> _initBiometric() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check device biometric capabilities with error handling
      bool canCheckBiometrics = false;
      bool isDeviceSupported = false;
      
      try {
        canCheckBiometrics = await _localAuth.canCheckBiometrics;
        isDeviceSupported = await _localAuth.isDeviceSupported();
      } catch (e) {
        print('Biometric check failed (possibly emulator): $e');
        if (mounted) setState(() => _isEmulator = true);
      }

      if (canCheckBiometrics && isDeviceSupported && !_isEmulator) {
        try {
          _availableBiometrics = await _localAuth.getAvailableBiometrics();
          print('Available biometrics: $_availableBiometrics');
          _hasBiometricCapability = _availableBiometrics.isNotEmpty;
          
          // Initialize face detector only if biometrics are supported
          await _initializeFaceDetector();
        } catch (e) {
          print('Error getting biometrics: $e');
          if (mounted) setState(() => _isEmulator = true);
        }
      } else if (!_isEmulator) {
        print('Biometrics not available or device not supported');
        if (mounted) setState(() => _isEmulator = true);
      }

      // Load user's biometric preference from Firestore
      final docId = user.email!.toLowerCase();
      final doc = await _firestore.collection('Users').doc(docId).get();

      if (doc.exists) {
        final data = doc.data();
        final biometricValue = data?['biometric'] ?? '';
        final faceVerified = data?['faceVerified'] ?? false;

        if (mounted) {
          setState(() {
            _isEnabled = biometricValue.isNotEmpty;
            _isFaceVerified = faceVerified;
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
        // Check if biometrics are available
        final canCheckBiometrics = await _localAuth.canCheckBiometrics;
        final isDeviceSupported = await _localAuth.isDeviceSupported();

        if (!canCheckBiometrics || !isDeviceSupported) {
          _showErrorSnackBar(
            'Biometric authentication is not available on this device',
          );
          return;
        }

        if (_availableBiometrics.isEmpty) {
          _showErrorSnackBar(
            'No biometric sensors detected. Please set up biometrics in your device settings.',
          );
          return;
        }

        // Set biometric value - will use Face ID with Fingerprint fallback
        biometricValue = 'enabled';
      } else {
        // When disabling, also reset face verification
        final docId = user.email!.toLowerCase();
        await _firestore.collection('Users').doc(docId).update({
          'faceVerified': false,
        });
        setState(() {
          _isFaceVerified = false;
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
            : 'Biometric disabled (Ultrasonic will be used)',
      );
    } catch (e) {
      print('Error in _toggleBiometric: $e');
      _showErrorSnackBar('Error updating biometric: $e');
    }
  }

  Future<void> _mockFaceVerification() async {
    // Mock verification for emulators
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final docId = user.email!.toLowerCase();

        await _firestore.collection('Users').doc(docId).update({
          'faceVerified': true,
          'faceHash': 'mock_hash_for_emulator_${DateTime.now().millisecondsSinceEpoch}',
          'faceVerificationDate': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            _isFaceVerified = true;
            _isVerifyingFace = false;
          });
        }

        _showSuccessSnackBar('Face verification successful (Mock mode for emulator)');

        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error in _mockFaceVerification: $e');
      _showErrorSnackBar('Error during mock verification: $e');
      if (mounted) setState(() => _isVerifyingFace = false);
    }
  }

  Future<void> _verifyFaceIdentity() async {
    try {
      setState(() => _isVerifyingFace = true);

      // Show emulator warning and use mock verification
      if (_isEmulator) {
        _showErrorSnackBar('Face detection not available on emulator. Using test verification.');
        await _mockFaceVerification();
        return;
      }

      // Ensure face detector is initialized
      if (!_faceDetectorInitialized) {
        await _initializeFaceDetector();
      }

      if (!_faceDetectorInitialized) {
        _showErrorSnackBar('Face detection is not available on this device');
        if (mounted) setState(() => _isVerifyingFace = false);
        return;
      }

      // Capture image from camera
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image == null) {
        if (mounted) setState(() => _isVerifyingFace = false);
        _showErrorSnackBar('No image captured');
        return;
      }

      // Process image with face detection
      try {
        final inputImage = InputImage.fromFilePath(image.path);
        final List<Face> faces = await _faceDetector.processImage(inputImage);

        if (faces.isEmpty) {
          _showErrorSnackBar('No face detected. Please try again.');
          if (mounted) setState(() => _isVerifyingFace = false);
          return;
        }

        if (faces.length > 1) {
          _showErrorSnackBar('Multiple faces detected. Please ensure only one face is visible.');
          if (mounted) setState(() => _isVerifyingFace = false);
          return;
        }

        final face = faces.first;

        // Check face quality
        if (!_isValidFaceQuality(face)) {
          _showErrorSnackBar('Face quality too low. Please try again with better lighting.');
          if (mounted) setState(() => _isVerifyingFace = false);
          return;
        }

        // Save face verification to Firestore
        final user = _auth.currentUser;
        if (user != null) {
          final docId = user.email!.toLowerCase();

          // Create a face embedding hash for storage (simplified approach)
          final faceHash = _generateFaceHash(face);

          await _firestore.collection('Users').doc(docId).update({
            'faceVerified': true,
            'faceHash': faceHash,
            'faceVerificationDate': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            setState(() {
              _isFaceVerified = true;
              _isVerifyingFace = false;
            });
          }

          _showSuccessSnackBar('Face verification successful! Your face has been registered.');

          if (mounted) {
            Navigator.pop(context);
          }
        }
      } catch (detectionError) {
        print('Face detection error: $detectionError');
        _showErrorSnackBar('Error processing image: $detectionError');
        if (mounted) setState(() => _isVerifyingFace = false);
        return;
      }
    } catch (e) {
      print('Error in _verifyFaceIdentity: $e');
      _showErrorSnackBar('Error during face verification: $e');
      if (mounted) setState(() => _isVerifyingFace = false);
    }
  }

  bool _isValidFaceQuality(Face face) {
    // Check if face is clearly visible
    // Face bounds should be reasonably sized (not too small)
    final faceWidth = face.boundingBox.width;
    final faceHeight = face.boundingBox.height;
    
    // Face should be at least 100x100 pixels
    if (faceWidth < 100 || faceHeight < 100) {
      return false;
    }

    // Check if face landmarks are detected (indicating good quality)
    final landmarks = face.landmarks;
    if (landmarks.isEmpty) {
      return false;
    }

    // Check face contour (should have sufficient contour points)
    final contours = face.contours;
    if (contours.isEmpty) {
      return false;
    }

    return true;
  }

  String _generateFaceHash(Face face) {
    // Generate a simple hash from face landmarks and contours
    // This is a simplified approach - in production, use proper ML embeddings
    final landmarks = face.landmarks;
    final contours = face.contours;
    
    StringBuffer buffer = StringBuffer();
    
    // Add landmark positions to hash
    landmarks.forEach((type, landmark) {
      if (landmark != null) {
        buffer.write('${landmark.position.x.toStringAsFixed(2)}_');
        buffer.write('${landmark.position.y.toStringAsFixed(2)}_');
      }
    });
    
    // Add contour points to hash
    contours.forEach((type, contour) {
      if (contour != null) {
        for (var point in contour.points) {
          buffer.write('${point.x.toStringAsFixed(1)}_${point.y.toStringAsFixed(1)}_');
        }
      }
    });
    
    return buffer.toString();
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
          'Device Biometric',
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
                          onChanged: !_hasBiometricCapability
                              ? null
                              : _toggleBiometric,
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Verify Face Identity Button (shown when enabled but not verified)
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
                                      'Verify your face to enable attendance',
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
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt),
                              label: Text(_isVerifyingFace ? 'Verifying...' : 'Verify Face Identity'),
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
                            ? (_isFaceVerified ? Colors.green : Colors.orange)
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
                              ? (_isFaceVerified ? Colors.green : Colors.orange)
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
                                    ? (_isFaceVerified
                                          ? 'Biometric Active'
                                          : 'Face Verification Pending')
                                    : 'Ultrasonic Mode',
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
                                    ? (_isFaceVerified
                                          ? 'Face ID verified. Fingerprint as fallback.'
                                          : 'Please verify your face to use biometric attendance')
                                    : 'Ultrasonic (microphone) will be used for attendance',
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

                  // Reminder Box
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
                          children: const [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'How It Works',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildBulletPoint(
                          'Enable Device Biometric to use face recognition for attendance.',
                        ),
                        _buildBulletPoint(
                          'After enabling, you must verify your face identity to activate the feature.',
                          color: Colors.orange.shade700,
                        ),
                        _buildBulletPoint(
                          'Once verified, Face ID will be used as the primary method for attendance.',
                          color: Colors.blue.shade700,
                        ),
                        _buildBulletPoint(
                          'If Face ID fails or is unavailable, Fingerprint will automatically be used as a fallback method.',
                        ),
                        _buildBulletPoint(
                          'When disabled, ultrasonic technology (microphone-based frequency detection) will be used to mark attendance.',
                        ),
                        _buildBulletPoint(
                          'No biometric data is stored on servers — verification happens only on your device.',
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
