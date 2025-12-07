import 'package:flutter/material.dart';
import '../controller/fingerprint_verification_controller.dart';
import '../component/fingerprint_scan_button.dart';
import 'device_verification_page.dart';
import 'location_verification_page.dart';

class FingerprintVerificationPage extends StatefulWidget {
  final String sessionId;
  final String courseCode;
  final String courseName;
  final String sessionType;

  const FingerprintVerificationPage({
    Key? key,
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
    required this.sessionType,
  }) : super(key: key);

  @override
  State<FingerprintVerificationPage> createState() =>
      _FingerprintVerificationPageState();
}

class _FingerprintVerificationPageState
    extends State<FingerprintVerificationPage> {
  final FingerprintVerificationController _controller =
      FingerprintVerificationController();

  bool _isVerifying = false;
  bool _attendanceMarked = false;
  bool _fingerprintRegistered = false;

  @override
  void initState() {
    super.initState();
    _checkFingerprintRegistration();
  }

  /// Check if user has registered fingerprint
  Future<void> _checkFingerprintRegistration() async {
    final isRegistered = await _controller.checkFingerprintRegistration();
    setState(() => _fingerprintRegistered = isRegistered);

    if (!isRegistered) {
      _showErrorSnackBar(
        'Fingerprint not registered. Please register first in Device Settings.',
      );
    }
  }

  /// Verify fingerprint and mark attendance if successful
  Future<void> _verifyFingerprintAndMarkAttendance() async {
    if (!_fingerprintRegistered) {
      _showErrorSnackBar('Fingerprint is not registered.');
      return;
    }

    try {
      setState(() => _isVerifying = true);

      final user = _controller.getCurrentUser();
      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        setState(() => _isVerifying = false);
        return;
      }

      // Check available biometrics
      final availableBiometrics = await _controller.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        _showErrorSnackBar('No biometric methods available on this device');
        setState(() => _isVerifying = false);
        return;
      }

      // Authenticate with fingerprint
      final isAuthenticated = await _controller.authenticateWithFingerprint();

      if (isAuthenticated) {
        final bool? deviceVerified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => DeviceVerificationPage(
              sessionId: widget.sessionId,
              sessionName: widget.courseName,
              returnResultOnVerified: true,
            ),
          ),
        );

        if (deviceVerified == true) {
          // Device verified - proceed to location verification
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LocationVerificationPage(
                  sessionId: widget.sessionId,
                  sessionName: widget.courseName,
                  detectedFrequency: 0, // No frequency for fingerprint
                ),
              ),
            );
          }
        } else {
          _showErrorSnackBar('Device verification cancelled or failed.');
          setState(() => _isVerifying = false);
        }
      } else {
        _showErrorSnackBar('Fingerprint verification failed');
        setState(() => _isVerifying = false);
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
      setState(() => _isVerifying = false);
    }
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
    // Calculate the available height of the screen (total height minus AppBar height and system padding)
    // kToolbarHeight is a constant for the AppBar's height.
    final double availableHeight =
        MediaQuery.of(context).size.height -
        kToolbarHeight -
        MediaQuery.of(context).padding.top;

    // The 32.0 accounts for the 16.0 padding applied to the SingleChildScrollView on top and bottom.
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
            'Mark Attendance',
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
            // 1. Force the inner box (Column) to take up the minimum height of the available viewport
            constraints: BoxConstraints(minHeight: minBodyHeight),
            child: IntrinsicHeight(
              child: Column(
                // 2. Center all children vertically within the full-height space
                mainAxisAlignment: MainAxisAlignment.center,
                // Ensure children span the width
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Session Info
                  // Container(
                  //   padding: const EdgeInsets.all(16),
                  //   decoration: BoxDecoration(
                  //     color: Colors.white,
                  //     borderRadius: BorderRadius.circular(12),
                  //     boxShadow: [
                  //       BoxShadow(
                  //         color: Colors.black.withOpacity(0.1),
                  //         blurRadius: 8,
                  //         offset: const Offset(0, 2),
                  //       ),
                  //     ],
                  //   ),
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Text(
                  //         widget.courseName,
                  //         style: const TextStyle(
                  //           fontSize: 18,
                  //           fontWeight: FontWeight.bold,
                  //           color: Colors.black87,
                  //         ),
                  //       ),
                  //       const SizedBox(height: 8),
                  //       Row(
                  //         children: [
                  //           const Text(
                  //             'Course Code: ',
                  //             style: TextStyle(
                  //               fontSize: 14,
                  //               color: Colors.grey,
                  //             ),
                  //           ),
                  //           Text(
                  //             widget.courseCode,
                  //             style: const TextStyle(
                  //               fontSize: 14,
                  //               fontWeight: FontWeight.w600,
                  //               color: Colors.black87,
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //       const SizedBox(height: 6),
                  //       Row(
                  //         children: [
                  //           const Text(
                  //             'Session Type: ',
                  //             style: TextStyle(
                  //               fontSize: 14,
                  //               color: Colors.grey,
                  //             ),
                  //           ),
                  //           Text(
                  //             widget.sessionType,
                  //             style: TextStyle(
                  //               fontSize: 14,
                  //               fontWeight: FontWeight.w600,
                  //               color: Colors.orange,
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //     ],
                  //   ),
                  // ),

                  // const SizedBox(height: 24),

                  // Fingerprint Status Info
                  // if (!_fingerprintRegistered)
                  //   Container(
                  //     padding: const EdgeInsets.all(16),
                  //     decoration: BoxDecoration(
                  //       color: Colors.red.shade50,
                  //       border: Border.all(color: Colors.red, width: 2),
                  //       borderRadius: BorderRadius.circular(12),
                  //     ),
                  //     child: Row(
                  //       children: [
                  //         Icon(
                  //           Icons.error_outline,
                  //           color: Colors.red.shade700,
                  //           size: 24,
                  //         ),
                  //         const SizedBox(width: 12),
                  //         Expanded(
                  //           child: Column(
                  //             crossAxisAlignment: CrossAxisAlignment.start,
                  //             children: [
                  //               const Text(
                  //                 'Fingerprint Not Registered',
                  //                 style: TextStyle(
                  //                   fontSize: 16,
                  //                   fontWeight: FontWeight.bold,
                  //                   color: Colors.red,
                  //                 ),
                  //               ),
                  //               const SizedBox(height: 4),
                  //               Text(
                  //                 'Please register your fingerprint first in Device Settings.',
                  //                 style: TextStyle(
                  //                   fontSize: 12,
                  //                   color: Colors.red.shade700,
                  //                 ),
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   )
                  // else
                  //   Container(
                  //     padding: const EdgeInsets.all(16),
                  //     decoration: BoxDecoration(
                  //       color: Colors.green.shade50,
                  //       border: Border.all(color: Colors.green, width: 2),
                  //       borderRadius: BorderRadius.circular(12),
                  //     ),
                  //     child: Row(
                  //       children: [
                  //         Icon(
                  //           Icons.check_circle,
                  //           color: Colors.green.shade700,
                  //           size: 24,
                  //         ),
                  //         const SizedBox(width: 12),
                  //         Expanded(
                  //           child: Column(
                  //             crossAxisAlignment: CrossAxisAlignment.start,
                  //             children: [
                  //               const Text(
                  //                 'Fingerprint Registered',
                  //                 style: TextStyle(
                  //                   fontSize: 16,
                  //                   fontWeight: FontWeight.bold,
                  //                   color: Colors.green,
                  //                 ),
                  //               ),
                  //               const SizedBox(height: 4),
                  //               Text(
                  //                 'Ready for fingerprint verification',
                  //                 style: TextStyle(
                  //                   fontSize: 12,
                  //                   color: Colors.green.shade700,
                  //                 ),
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),

                  // Main Verification Button
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (!_attendanceMarked)
                          FingerprintScanButton(
                            isRegistered: _fingerprintRegistered,
                            isVerifying: _isVerifying,
                            onTap: _verifyFingerprintAndMarkAttendance,
                          ),

                        //   SizedBox(
                        //     width: double.infinity,
                        //     child: ElevatedButton.icon(
                        //       onPressed: _fingerprintRegistered && !_isVerifying
                        //           ? _verifyFingerprintAndMarkAttendance
                        //           : null,
                        //       icon: _isVerifying
                        //           ? const SizedBox(
                        //               width: 20,
                        //               height: 20,
                        //               child: CircularProgressIndicator(
                        //                 strokeWidth: 2,
                        //                 valueColor:
                        //                     AlwaysStoppedAnimation<Color>(
                        //                       Colors.grey,
                        //                     ),
                        //               ),
                        //             )
                        //           : const Icon(Icons.fingerprint),
                        //       label: Text(
                        //         _isVerifying
                        //             ? 'Verifying...'
                        //             : 'Scan Fingerprint',
                        //         style: TextStyle(color: Colors.white),
                        //       ),
                        //     ),
                        //   ),
                        // ] else ...[
                        //   Icon(
                        //     Icons.check_circle,
                        //     size: 64,
                        //     color: Colors.green.shade700,
                        //   ),
                        //   const SizedBox(height: 16),
                        //   const Text(
                        //     'Attendance Marked!',
                        //     style: TextStyle(
                        //       fontSize: 20,
                        //       fontWeight: FontWeight.bold,
                        //       color: Colors.green,
                        //     ),
                        //   ),
                        //   const SizedBox(height: 8),
                        //   Text(
                        //     'via Fingerprint Verification',
                        //     style: TextStyle(
                        //       fontSize: 14,
                        //       color: Colors.grey.shade600,
                        //     ),
                        //   ),
                        // ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Instructions
                  // Container(
                  //   padding: const EdgeInsets.all(16),
                  //   decoration: BoxDecoration(
                  //     color: Colors.white,
                  //     borderRadius: BorderRadius.circular(12),
                  //   ),
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Row(
                  //         children: [
                  //           Icon(
                  //             Icons.info_outline,
                  //             color: Colors.blue.shade700,
                  //             size: 20,
                  //           ),
                  //           const SizedBox(width: 8),
                  //           Text(
                  //             'Instructions',
                  //             style: TextStyle(
                  //               fontSize: 16,
                  //               fontWeight: FontWeight.bold,
                  //               color: Colors.blue.shade700,
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //       const SizedBox(height: 12),
                  //       _buildBulletPoint(
                  //         'Ensure your device is unlocked',
                  //       ),
                  //       _buildBulletPoint(
                  //         'Place your registered finger on the sensor',
                  //       ),
                  //       _buildBulletPoint(
                  //         'Hold steady until verification completes',
                  //       ),
                  //       _buildBulletPoint(
                  //         'Your attendance will be marked automatically upon successful verification',
                  //       ),
                  //       _buildBulletPoint(
                  //         'If verification fails, you can try again',
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
