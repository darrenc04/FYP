import 'package:flutter/material.dart';
import '../controller/device_verification_controller.dart';
import '../component/verification_status_display.dart';
import 'location_verification_page.dart';

class DeviceVerificationPage extends StatefulWidget {
  final String sessionId;
  final String sessionName;
  final double? detectedFrequency;
  final bool returnResultOnVerified;

  const DeviceVerificationPage({
    super.key,
    required this.sessionId,
    required this.sessionName,
    this.detectedFrequency,
    this.returnResultOnVerified = false,
  });

  @override
  State<DeviceVerificationPage> createState() => _DeviceVerificationPageState();
}

class _DeviceVerificationPageState extends State<DeviceVerificationPage> {
  final DeviceVerificationController _controller =
      DeviceVerificationController();

  bool _verifying = true;
  bool _verified = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _verifyDeviceToken();
  }

  Future<void> _verifyDeviceToken() async {
    final result = await _controller.verifyDevice(widget.sessionId);

    setState(() {
      _verifying = false;
      _verified = result.isVerified;
      _errorMessage = result.errorMessage;
    });

    if (result.isVerified) {
      // Wait a moment to show success
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        // Check if we should return result or navigate
        if (widget.returnResultOnVerified) {
          // For fingerprint/face verification: return true to caller
          Navigator.pop(context, true);
        } else {
          // For ultrasonic verification: navigate to location verification
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LocationVerificationPage(
                sessionId: widget.sessionId,
                sessionName: widget.sessionName,
                detectedFrequency: widget.detectedFrequency ?? 0,
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF49555B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF49555B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Device Verification',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: VerificationStatusDisplay(
            isVerifying: _verifying,
            isVerified: _verified,
            errorMessage: _errorMessage,
            onGoBack: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}
