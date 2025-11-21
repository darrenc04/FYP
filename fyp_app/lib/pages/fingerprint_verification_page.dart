import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
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
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isVerifying = false;
  bool _attendanceMarked = false;
  bool _fingerprintRegistered = false;
  String _verificationStatus = '';

  @override
  void initState() {
    super.initState();
    _checkFingerprintRegistration();
  }

  /// Check if user has registered fingerprint
  Future<void> _checkFingerprintRegistration() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userId = user.email!.toLowerCase();
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      final isFingerprintVerified =
          userDoc.data()?['fingerprintVerified'] ?? false;

      setState(() => _fingerprintRegistered = isFingerprintVerified);

      if (!isFingerprintVerified) {
        _showErrorSnackBar(
          'Fingerprint not registered. Please register first in Device Settings.',
        );
      }
    } catch (e) {
      print('Error checking fingerprint registration: $e');
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

      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        setState(() => _isVerifying = false);
        return;
      }

      // Get available biometrics
      try {
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        if (availableBiometrics.isEmpty) {
          _showErrorSnackBar('No biometric methods available on this device');
          setState(() => _isVerifying = false);
          return;
        }
      } catch (e) {
        _showErrorSnackBar('Error checking biometric availability: $e');
        setState(() => _isVerifying = false);
        return;
      }

      // Authenticate with fingerprint
      try {
        final isAuthenticated = await _localAuth.authenticate(
          localizedReason: 'Verify your fingerprint to mark attendance',
          options: const AuthenticationOptions(
            stickyAuth: false,
            biometricOnly: true,
          ),
        );

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
                    detectedFrequency: null, // No frequency for fingerprint
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
        _showErrorSnackBar('Error during fingerprint verification: $e');
        setState(() => _isVerifying = false);
      }
    } catch (e) {
      print('Error in _verifyFingerprintAndMarkAttendance: $e');
      _showErrorSnackBar('Error: $e');
      setState(() => _isVerifying = false);
    }
  }

  /// Mark attendance in Firestore after successful fingerprint verification
  Future<void> _markAttendance(String userId) async {
    try {
      _showInfoSnackBar('Marking attendance...');

      // Create attendance record
      final attendanceData = {
        'studentId': userId,
        'sessionId': widget.sessionId,
        'courseCode': widget.courseCode,
        'courseName': widget.courseName,
        'sessionType': widget.sessionType,
        'markedAt': FieldValue.serverTimestamp(),
        'verificationMethod': 'fingerprint', // Fingerprint verification
        'status': 'present',
      };

      // Add to Attendance collection
      await _firestore.collection('Attendance').add(attendanceData);

      // Also update user's session attendance status
      await _firestore
          .collection('Sessions')
          .doc(widget.sessionId)
          .collection('Attendance')
          .doc(userId)
          .set({
            'status': 'present',
            'markedAt': FieldValue.serverTimestamp(),
            'verificationMethod': 'fingerprint',
          }, SetOptions(merge: true));

      setState(() {
        _attendanceMarked = true;
        _isVerifying = false;
      });

      _showSuccessSnackBar('Attendance marked successfully!');

      // Wait 2 seconds then navigate back
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      print('Error in _markAttendance: $e');
      _showErrorSnackBar('Error marking attendance: $e');
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
                        if (!_attendanceMarked) ...[
                          const Text(
                            'Verify Your Fingerprint',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),

                          GestureDetector(
                            onTap: _fingerprintRegistered && !_isVerifying
                                ? _verifyFingerprintAndMarkAttendance
                                : null, // Disable tap if not registered or already verifying
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _fingerprintRegistered && !_isVerifying
                                    ? Colors
                                          .blueGrey
                                          .shade700 // Ready state
                                    : Colors.grey.shade700, // Disabled state
                                border: Border.all(
                                  color: _isVerifying
                                      ? Colors.orange
                                      : Colors.white, // Highlight if verifying
                                  width: _isVerifying ? 4 : 2,
                                ),
                              ),
                              child: Icon(
                                Icons.fingerprint,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
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

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
