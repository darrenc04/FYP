import 'package:flutter/material.dart';
import '../controller/face_verification_controller.dart';
import '../component/face_verification_button.dart';
import '../component/verification_instructions_box.dart';
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
  final FaceVerificationController _controller = FaceVerificationController();

  bool _isVerifying = false;
  double _blinkConfidence = 0.0;
  int _blinksDetected = 0;

  /// Verify both face match and eye blinking for liveness
  Future<void> _verifyFaceAndEyeBlinkAndMarkAttendance() async {
    try {
      setState(() => _isVerifying = true);

      final userEmail = _controller.getUserEmail();
      if (userEmail == null) {
        _showErrorSnackBar('User not authenticated');
        setState(() => _isVerifying = false);
        return;
      }

      // Verify DeepFace API is available
      final isServerHealthy = await _controller.checkServerHealth();
      if (!isServerHealthy) {
        _showErrorSnackBar('DeepFace server is not responding.');
        setState(() => _isVerifying = false);
        return;
      }

      // Capture video from camera
      final video = await _controller.captureVideo();
      if (video == null) {
        _showErrorSnackBar('No video captured');
        setState(() => _isVerifying = false);
        return;
      }

      // Verify face and detect blinks
      _showInfoSnackBar('Analyzing face and detecting blinks...');
      final result = await _controller.verifyFaceAndDetectBlinks(
        userEmail,
        video,
      );

      setState(() {
        _blinksDetected = result.blinksDetected;
        _blinkConfidence = result.blinkConfidence;
      });

      if (result.isVerified && mounted) {
        _showSuccessSnackBar(result.successMessage);
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
      } else {
        _showErrorSnackBar(result.failureReason);
        setState(() => _isVerifying = false);
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
      setState(() => _isVerifying = false);
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
                        FaceVerificationButton(
                          isVerifying: _isVerifying,
                          blinksDetected: _blinksDetected,
                          onTap: _verifyFaceAndEyeBlinkAndMarkAttendance,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Instructions
                  const VerificationInstructionsBox(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
