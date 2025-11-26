import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'device_verification_page.dart';
import 'location_verification_page.dart';

class FaceVerificationPageV2 extends StatefulWidget {
  final String sessionId;
  final String courseCode;
  final String courseName;
  final String sessionType;

  const FaceVerificationPageV2({
    Key? key,
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
    required this.sessionType,
  }) : super(key: key);

  @override
  State<FaceVerificationPageV2> createState() => _FaceVerificationPageV2State();
}

class _FaceVerificationPageV2State extends State<FaceVerificationPageV2> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // API Configuration
  static const String DEEPFACE_API_URL = 'http://192.168.100.177:5000';

  bool _isVerifying = false;
  double _blinkConfidence = 0.0;
  int _blinksDetected = 0;

  @override
  void initState() {
    super.initState();
  }

  /// Verify both face match and eye blinking for liveness
  Future<void> _verifyFaceAndEyeBlinkAndMarkAttendance() async {
    try {
      setState(() => _isVerifying = true);

      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        setState(() => _isVerifying = false);
        return;
      }

      // Verify DeepFace API is available
      try {
        final healthResponse = await http
            .get(Uri.parse('$DEEPFACE_API_URL/health'))
            .timeout(const Duration(seconds: 5));

        if (healthResponse.statusCode != 200) {
          _showErrorSnackBar('DeepFace server is not responding.');
          setState(() => _isVerifying = false);
          return;
        }
      } catch (e) {
        _showErrorSnackBar('Cannot reach DeepFace server: $e');
        setState(() => _isVerifying = false);
        return;
      }

      // Capture video from camera for blink detection + face verification
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxDuration: const Duration(seconds: 10),
      );

      if (video == null) {
        _showErrorSnackBar('No video captured');
        setState(() => _isVerifying = false);
        return;
      }

      // Send video to backend for both face verification and eye blink detection
      final result = await _verifyFaceAndDetectBlinks(
        user.email!.toLowerCase(),
        video,
      );

      if (result['success'] && mounted) {
        // Both face match and eye blink verified - proceed to device verification
        final bool? deviceVerified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => DeviceVerificationPage(
              sessionId: widget.sessionId,
              sessionName: widget.courseName,
              detectedFrequency: null,
              returnResultOnVerified: true,
            ),
          ),
        );

        if (deviceVerified != true) {
          _showErrorSnackBar('Device verification cancelled or failed.');
          setState(() => _isVerifying = false);
          return;
        }

        // Device verified - proceed to location verification
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LocationVerificationPage(
              sessionId: widget.sessionId,
              sessionName: widget.courseName,
              detectedFrequency: 0,
              faceConfidence: _blinkConfidence,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in _verifyFaceAndEyeBlinkAndMarkAttendance: $e');
      _showErrorSnackBar('Error: $e');
      setState(() => _isVerifying = false);
    }
  }

  /// Send video to backend for both face verification and eye blink detection
  /// Returns map with success status and verification details
  Future<Map<String, dynamic>> _verifyFaceAndDetectBlinks(
    String userId,
    XFile video,
  ) async {
    try {
      _showInfoSnackBar('Analyzing face and detecting blinks...');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$DEEPFACE_API_URL/verify-face-and-blinks'),
      );

      request.fields['user_id'] = userId;
      request.files.add(await http.MultipartFile.fromPath('video', video.path));

      final response = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final responseBody = await response.stream.bytesToString();

      debugPrint('Face + Blink verification response status: ${response.statusCode}');
      debugPrint('Face + Blink verification response body: $responseBody');

      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(responseBody);
          final blinksDetected = jsonData['blinks_detected'] as int? ?? 0;
          final faceConfidence = jsonData['face_confidence'] as double? ?? 0.0;
          final blinkConfidence = jsonData['blink_confidence'] as double? ?? 0.0;
          final isLive = jsonData['is_live'] ?? false;

          setState(() {
            _blinksDetected = blinksDetected;
            _blinkConfidence = blinkConfidence;
          });

          if (isLive && blinksDetected >= 2 && faceConfidence >= 20.0) {
            _showSuccessSnackBar(
              'Face matched! Blinks: $blinksDetected, Confidence: ${faceConfidence.toStringAsFixed(2)}%',
            );
            return {'success': true, 'details': jsonData};
          } else {
            String errorMsg = 'Verification failed. ';
            if (faceConfidence < 20.0) {
              errorMsg +=
                  'Face does not match (${faceConfidence.toStringAsFixed(2)}% - need at least 20%). ';
            }
            if (blinksDetected < 2) {
              errorMsg += 'Need at least 2 blinks, detected: $blinksDetected. ';
            }
            if (!isLive) {
              errorMsg += 'No live face detected. ';
            }
            _showErrorSnackBar(errorMsg);
            setState(() => _isVerifying = false);
            return {'success': false, 'error': errorMsg};
          }
        } catch (e) {
          _showErrorSnackBar('Error parsing response: $e');
          setState(() => _isVerifying = false);
          return {'success': false, 'error': 'Parse error: $e'};
        }
      } else if (response.statusCode == 404) {
        _showErrorSnackBar('User face not registered. Please register first.');
        setState(() => _isVerifying = false);
        return {'success': false, 'error': 'Face not registered'};
      } else {
        _showErrorSnackBar('Verification failed: ${response.statusCode}');
        setState(() => _isVerifying = false);
        return {'success': false, 'error': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('Error in _verifyFaceAndDetectBlinks: $e');
      _showErrorSnackBar('Verification error: $e');
      setState(() => _isVerifying = false);
      return {'success': false, 'error': '$e'};
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
    final double availableHeight =
        MediaQuery.of(context).size.height -
        kToolbarHeight -
        MediaQuery.of(context).padding.top;

    final double minBodyHeight = availableHeight - 32.0;

    return WillPopScope(
      onWillPop: () async => !_isVerifying,
      child: Scaffold(
        backgroundColor: const Color(0xFF2C3E50),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2C3E50),
          elevation: 0,
          leading: _isVerifying
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
          title: const Text(
            'Mark Attendance (Eye Blink)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minBodyHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),

                  // Main Verification Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                      const Text(
                            'Verify with Face & Blinks',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        const SizedBox(height: 24),

                        // Eye blink detection button
                        GestureDetector(
                          onTap: !_isVerifying
                              ? _verifyFaceAndEyeBlinkAndMarkAttendance
                              : null,
                          child: Column(
                            children: [
                              _isVerifying
                                  ? const SizedBox(
                                      width: 160,
                                      height: 160,
                                      child: Center(
                                        child: SizedBox(
                                          width: 80,
                                          height: 80,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 4,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.orange,
                                                ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.videocam,
                                      size: 160,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                              const SizedBox(height: 16),
                              Text(
                                _isVerifying
                                    ? 'Verifying Face & Blinks...'
                                    : 'Tap to Record Video',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _isVerifying
                                      ? Colors.orange
                                      : Colors.grey.shade400,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_blinksDetected > 0)
                                Text(
                                  'Blinks Detected: $_blinksDetected',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade300,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Instructions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade300,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildBulletPoint(
                          'Ensure good lighting and clear face visibility',
                        ),
                        _buildBulletPoint(
                          'Face should be directly facing the camera',
                        ),
                        _buildBulletPoint(
                          'Blink your eyes naturally at least 2 times',
                        ),
                        _buildBulletPoint(
                          'Video duration: max 10 seconds',
                        ),
                        _buildBulletPoint(
                          'Remove sunglasses or face obscurities',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
