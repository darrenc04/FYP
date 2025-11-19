import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FaceVerificationPage extends StatefulWidget {
  final String sessionId;
  final String courseCode;
  final String courseName;
  final String sessionType; // 'Lecture Class' or 'Tutorial Class'

  const FaceVerificationPage({
    Key? key,
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
    required this.sessionType,
  }) : super(key: key);

  @override
  State<FaceVerificationPage> createState() => _FaceVerificationPageState();
}

class _FaceVerificationPageState extends State<FaceVerificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // API Configuration
  static const String DEEPFACE_API_URL = 'http://192.168.100.177:5000';

  bool _isVerifying = false;
  bool _attendanceMarked = false;
  bool _faceRegistered = false;
  double _verificationConfidence = 0.0;
  String _verificationStatus = '';

  @override
  void initState() {
    super.initState();
    _checkFaceRegistration();
  }

  /// Check if user has a registered face
  Future<void> _checkFaceRegistration() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userId = user.email!.toLowerCase();
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      final isFaceVerified = userDoc.data()?['faceVerified'] ?? false;

      setState(() => _faceRegistered = isFaceVerified);

      if (!isFaceVerified) {
        _showErrorSnackBar(
          'Face not registered. Please register your face first.',
        );
      }
    } catch (e) {
      print('Error checking face registration: $e');
    }
  }

  /// Verify face and mark attendance if verification succeeds
  Future<void> _verifyFaceAndMarkAttendance() async {
    if (!_faceRegistered) {
      _showErrorSnackBar('Face is not registered. Please register first.');
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

      // Capture image from camera
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image == null) {
        _showErrorSnackBar('No image captured');
        setState(() => _isVerifying = false);
        return;
      }

      // Verify face against registered embedding
      await _verifyFaceAgainstRegistered(user.email!.toLowerCase(), image);
    } catch (e) {
      print('Error in _verifyFaceAndMarkAttendance: $e');
      _showErrorSnackBar('Error: $e');
      setState(() => _isVerifying = false);
    }
  }

  /// Send image to backend for verification
  Future<void> _verifyFaceAgainstRegistered(String userId, XFile image) async {
    try {
      _showInfoSnackBar('Verifying your face...');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$DEEPFACE_API_URL/verify-face'),
      );

      request.fields['user_id'] = userId;
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final responseBody = await response.stream.bytesToString();

      print('Verify response status: ${response.statusCode}');
      print('Verify response body: $responseBody');

      if (response.statusCode == 200) {
        // Parse response
        try {
          final jsonData = jsonDecode(responseBody);
          final isMatch = jsonData['is_match'] ?? false;
          final confidence = jsonData['confidence'] ?? 0.0;

          setState(() => _verificationConfidence = confidence);

          if (isMatch) {
            // Face matched - mark attendance
            await _markAttendance(userId);
          } else {
            _showErrorSnackBar(
              'Face does not match. Confidence: ${confidence.toStringAsFixed(2)}%',
            );
            setState(() => _isVerifying = false);
          }
        } catch (e) {
          _showErrorSnackBar('Error parsing response: $e');
          setState(() => _isVerifying = false);
        }
      } else if (response.statusCode == 404) {
        _showErrorSnackBar('User face not found. Please register first.');
        setState(() => _isVerifying = false);
      } else {
        _showErrorSnackBar('Verification failed: ${response.statusCode}');
        setState(() => _isVerifying = false);
      }
    } catch (e) {
      print('Error in _verifyFaceAgainstRegistered: $e');
      _showErrorSnackBar('Verification error: $e');
      setState(() => _isVerifying = false);
    }
  }

  /// Mark attendance in Firestore after successful face verification
  Future<void> _markAttendance(String userId) async {
    try {
      _showInfoSnackBar('Marking attendance...');

      final user = _auth.currentUser;
      if (user == null) return;

      // Create attendance record
      final attendanceData = {
        'studentId': userId,
        'sessionId': widget.sessionId,
        'courseCode': widget.courseCode,
        'courseName': widget.courseName,
        'sessionType': widget.sessionType,
        'markedAt': FieldValue.serverTimestamp(),
        'verificationMethod': 'face', // Face verification
        'faceConfidence': _verificationConfidence,
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
            'verificationMethod': 'face',
            'faceConfidence': _verificationConfidence,
          }, SetOptions(merge: true));

      setState(() {
        _attendanceMarked = true;
        _isVerifying = false;
      });

      _showSuccessSnackBar(
        'Attendance marked successfully! Confidence: ${_verificationConfidence.toStringAsFixed(2)}%',
      );

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
    // Calculate the available height of the screen
    final double availableHeight =
        MediaQuery.of(context).size.height -
        kToolbarHeight -
        MediaQuery.of(context).padding.top;

    // Subtract the total vertical padding (16.0 top + 16.0 bottom)
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
            // 1. Force the inner box to take up the minimum height of the available viewport
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
                  //               color: widget.sessionType == 'Tutorial'
                  //                   ? Colors.orange
                  //                   : Colors.blue,
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  const SizedBox(height: 24),

                  // Face Status Info
                  // if (!_faceRegistered)
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
                  //                 'Face Not Registered',
                  //                 style: TextStyle(
                  //                   fontSize: 16,
                  //                   fontWeight: FontWeight.bold,
                  //                   color: Colors.red,
                  //                 ),
                  //               ),
                  //               const SizedBox(height: 4),
                  //               Text(
                  //                 'Please register your face first in Device Settings.',
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
                  //                 'Face Registered',
                  //                 style: TextStyle(
                  //                   fontSize: 16,
                  //                   fontWeight: FontWeight.bold,
                  //                   color: Colors.green,
                  //                 ),
                  //               ),
                  //               const SizedBox(height: 4),
                  //               Text(
                  //                 'Ready for face verification',
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

                  // const SizedBox(height: 24),

                  // Main Verification Button
                  Container(
                    padding: const EdgeInsets.all(20),

                    child: Column(
                      children: [
                        if (!_attendanceMarked) ...[
                          const Text(
                            'Verify Your Face',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),

                          
                          GestureDetector(
                            onTap: _faceRegistered && !_isVerifying
                                ? _verifyFaceAndMarkAttendance
                                : null,
                            child: Column(       
                              children: [
                                _isVerifying
                                    ? const SizedBox(
                                        width:
                                            160, 
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
                                    : Image.asset(
                                        'assets/faceid.png',
                                        fit: BoxFit.contain,
                                        height:
                                            160,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const FlutterLogo(size: 160),
                                      ),

                                const SizedBox(height: 8),

                                Text(
                                  _isVerifying
                                      ? 'Verifying Face...'
                                      : _faceRegistered
                                      ? 'Tap to Scan Face'
                                      : 'Face Not Registered',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _isVerifying
                                        ? Colors.orange
                                        : Colors.grey.shade400,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Instructions
                  // Container(
                  //   padding: const EdgeInsets.all(16),
                  //   decoration: BoxDecoration(
                  //     color: Colors.white,
                  //     borderRadius: BorderRadius.circular(12),
                  //   ),
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Row(
                  //         children: [
                  //           Icon(
                  //             Icons.info_outline,
                  //             color: Colors.blue.shade700,
                  //             size: 20,
                  //           ),
                  //           const SizedBox(width: 8),
                  //           Text(
                  //             'Instructions',
                  //             style: TextStyle(
                  //               fontSize: 16,
                  //               fontWeight: FontWeight.bold,
                  //               color: Colors.blue.shade700,
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //       const SizedBox(height: 12),
                  //       _buildBulletPoint(
                  //         'Ensure good lighting and clear face visibility',
                  //       ),
                  //       _buildBulletPoint(
                  //         'Face should be directly facing the camera',
                  //       ),
                  //       _buildBulletPoint(
                  //         'Remove sunglasses or face obscurities',
                  //       ),
                  //       _buildBulletPoint(
                  //         'Your face will be compared against your registered image',
                  //       ),
                  //       _buildBulletPoint(
                  //         'Verification requires at least 90% confidence match',
                  //       ),
                  //     ],
                  //   ),
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
