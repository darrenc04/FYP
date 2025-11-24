import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
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
  bool _verifying = true;
  bool _verified = false;
  String? _errorMessage;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  @override
  void initState() {
    super.initState();
    _verifyDeviceToken();
  }

  Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id; // Unique Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? '';
      }
    } catch (e) {
      debugPrint('Error getting device ID: $e');
    }
    return '';
  }

  Future<void> _verifyDeviceToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        setState(() {
          _verifying = false;
          _errorMessage = 'User not logged in';
        });
        return;
      }

      // Get user document
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user!.email!.toLowerCase())
          .get();

      if (!userDoc.exists) {
        setState(() {
          _verifying = false;
          _errorMessage = 'User data not found';
        });
        return;
      }

      final userData = userDoc.data();
      final storedDeviceToken = userData?['deviceToken'] ?? '';

      // Get current device ID dynamically
      final currentDeviceToken = await _getDeviceId();

      if (currentDeviceToken.isEmpty) {
        setState(() {
          _verifying = false;
          _errorMessage = 'Unable to get device ID';
        });
        return;
      }

      if (storedDeviceToken.isEmpty) {
        setState(() {
          _verifying = false;
          _errorMessage = 'No device registered for this account';
        });
        return;
      }

      if (storedDeviceToken != currentDeviceToken) {
        setState(() {
          _verifying = false;
          _errorMessage =
              'Device not authorized. Please use your registered device.';
        });
        return;
      }

      // NEW: Check if this device token already exists in the session attendance
      // Also check if the student has ALREADY marked attendance (or was revoked)
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final attendanceQuery = await FirebaseFirestore.instance
          .collection('Attendance')
          .where('sessionId', isEqualTo: widget.sessionId)
          .where('email', isEqualTo: user.email!.toLowerCase())
          .where(
            'markedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('markedAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      if (attendanceQuery.docs.isNotEmpty) {
        final attendanceDoc = attendanceQuery.docs.first;
        final status = attendanceDoc['status'];
        final revokedBy = attendanceDoc['revokedBy'];
        final revocationReason = attendanceDoc['revocationReason'];

        if (status == 'present') {
          setState(() {
            _verifying = false;
            _errorMessage =
                'You have already marked attendance for this session.';
          });
          return;
        } else if (status == 'absent' && revokedBy == 'teacher') {
          setState(() {
            _verifying = false;
            _errorMessage =
                'Your attendance was revoked by the teacher.\nReason: $revocationReason';
          });
          return;
        }
      }

      // Device verified, proceed to location verification
      setState(() {
        _verifying = false;
        _verified = true;
      });

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
                detectedFrequency: widget.detectedFrequency!,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Device verification error: $e');
      setState(() {
        _verifying = false;
        _errorMessage = 'Verification failed: ${e.toString()}';
      });
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_verifying) ...[
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Verifying Device...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else if (_verified) ...[
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.check, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Device Verified!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Proceeding to location verification...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ] else ...[
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Verification Failed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF49555B),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
