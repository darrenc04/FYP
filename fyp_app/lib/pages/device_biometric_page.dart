import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';

class DeviceBiometricPage extends StatefulWidget {
  const DeviceBiometricPage({Key? key}) : super(key: key);

  @override
  State<DeviceBiometricPage> createState() => _DeviceBiometricPageState();
}

class _DeviceBiometricPageState extends State<DeviceBiometricPage> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isEnabled = false;
  bool _isFaceVerified = false;
  List<BiometricType> _availableBiometrics = [];
  bool _isLoading = true;
  bool _hasBiometricCapability = false;

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Check device biometric capabilities
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (canCheckBiometrics && isDeviceSupported) {
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
        print('Available biometrics: $_availableBiometrics');
        _hasBiometricCapability = _availableBiometrics.isNotEmpty;
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

        setState(() {
          _isEnabled = biometricValue.isNotEmpty;
          _isFaceVerified = faceVerified;
        });
      }
    } catch (e) {
      print('Error in _initBiometric: $e');
      _showErrorSnackBar('Error loading biometric settings: $e');
    } finally {
      setState(() => _isLoading = false);
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

  Future<void> _verifyFaceIdentity() async {
    // TODO: Implement face verification logic later
    // For now, just show a placeholder message
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Face Verification'),
        content: const Text(
          'Face verification feature will be implemented soon. This will register your face for attendance marking.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
                              onPressed: _verifyFaceIdentity,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Verify Face Identity'),
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
