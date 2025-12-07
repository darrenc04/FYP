import 'package:flutter/material.dart';
import '../model/biometric_settings.dart';
import '../controller/biometric_controller.dart';
import '../component/biometric/biometric_toggle.dart';
import '../component/biometric/biometric_verification_card.dart';
import '../component/biometric/biometric_status_info.dart';
import '../component/biometric/biometric_info_box.dart';

class DeviceBiometricPageV2 extends StatefulWidget {
  const DeviceBiometricPageV2({Key? key}) : super(key: key);

  @override
  State<DeviceBiometricPageV2> createState() => _DeviceBiometricPageV2State();
}

class _DeviceBiometricPageV2State extends State<DeviceBiometricPageV2> {
  final BiometricController _controller = BiometricController();

  bool _isEnabled = false;
  bool _isFaceVerified = false;
  bool _isFingerprintVerified = false;
  bool _isLoading = true;
  bool _hasBiometricCapability = false;
  bool _isVerifyingFace = false;
  bool _isVerifyingFingerprint = false;
  bool _isMockMode =
      false; // Set to false for production; true for testing without biometrics

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    try {
      final settings = await _controller.loadBiometricSettings(
        isMockMode: _isMockMode,
      );

      if (mounted) {
        setState(() {
          _isEnabled = settings.isEnabled;
          _isFaceVerified = settings.isFaceVerified;
          _isFingerprintVerified = settings.isFingerprintVerified;
          _hasBiometricCapability = settings.hasBiometricCapability;
        });
      }
    } catch (e) {
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
      await _controller.toggleBiometric(
        value,
        hasBiometricCapability: _hasBiometricCapability,
        isMockMode: _isMockMode,
      );

      setState(() {
        _isEnabled = value;
        if (!value) {
          _isFaceVerified = false;
          _isFingerprintVerified = false;
        }
      });

      _showSuccessSnackBar(
        value
            ? 'Biometric enabled. Please verify your face identity.'
            : 'Biometric disabled',
      );
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _verifyFingerprint() async {
    try {
      setState(() => _isVerifyingFingerprint = true);

      if (_isMockMode) {
        _showInfoSnackBar('Mock Mode: Simulating fingerprint verification...');
      }

      final result = await _controller.verifyFingerprint(
        isMockMode: _isMockMode,
      );

      if (result['success'] == true) {
        if (result['isRegistration'] == true) {
          setState(() => _isFingerprintVerified = true);
        }
        _showSuccessSnackBar(result['message']);
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isVerifyingFingerprint = false);
    }
  }

  Future<void> _verifyFaceIdentity() async {
    try {
      setState(() => _isVerifyingFace = true);

      if (_isMockMode) {
        _showInfoSnackBar('Mock Mode: Simulating face verification...');
      } else {
        _showInfoSnackBar(
          'Registering your face with video (extracting multiple frames)...',
        );
      }

      final result = await _controller.verifyFaceIdentity(
        isMockMode: _isMockMode,
      );

      if (result['success'] == true) {
        if (result['isRegistration'] == true) {
          setState(() => _isFaceVerified = true);
        }
        _showSuccessSnackBar(result['message']);
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
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
                  BiometricToggle(
                    isEnabled: _isEnabled,
                    onChanged: _toggleBiometric,
                  ),

                  const SizedBox(height: 16),

                  // Verify Face Button
                  if (_isEnabled && !_isFaceVerified) ...[
                    BiometricVerificationCard(
                      title: 'Face Identity Required',
                      description: 'Register your face for attendance',
                      icon: Icons.face_retouching_natural,
                      color: Colors.orange,
                      buttonText: 'Register Face',
                      isVerifying: _isVerifyingFace,
                      onPressed: _verifyFaceIdentity,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Verify Fingerprint Button
                  if (_isEnabled && !_isFingerprintVerified) ...[
                    BiometricVerificationCard(
                      title: 'Fingerprint Registration',
                      description: 'Register your fingerprint for attendance',
                      icon: Icons.fingerprint,
                      color: Colors.blue,
                      buttonText: 'Register Fingerprint',
                      isVerifying: _isVerifyingFingerprint,
                      onPressed: _verifyFingerprint,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Status Info
                  BiometricStatusInfo(
                    isEnabled: _isEnabled,
                    isFaceVerified: _isFaceVerified,
                    isFingerprintVerified: _isFingerprintVerified,
                  ),

                  // Info Box
                  const SizedBox(height: 24),
                  BiometricInfoBox(isMockMode: _isMockMode),
                ],
              ),
            ),
    );
  }
}
