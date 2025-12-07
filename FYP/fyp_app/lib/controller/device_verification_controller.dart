import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../model/device_verification_result.dart';

class DeviceVerificationController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id; // Unique Android ID
      }
    } catch (e) {
      debugPrint('Error getting device ID: $e');
    }
    return '';
  }

  Future<DeviceVerificationResult> verifyDevice(String sessionId) async {
    try {
      final user = _auth.currentUser;
      if (user?.email == null) {
        return DeviceVerificationResult(
          isVerified: false,
          errorMessage: 'User not logged in',
        );
      }

      // Get user document
      final userDoc = await _firestore
          .collection('Users')
          .doc(user!.email!.toLowerCase())
          .get();

      if (!userDoc.exists) {
        return DeviceVerificationResult(
          isVerified: false,
          errorMessage: 'User data not found',
        );
      }

      final userData = userDoc.data();
      final storedDeviceToken = userData?['deviceToken'] ?? '';

      // Get current device ID dynamically
      final currentDeviceToken = await getDeviceId();

      if (currentDeviceToken.isEmpty) {
        return DeviceVerificationResult(
          isVerified: false,
          errorMessage: 'Unable to get device ID',
        );
      }

      if (storedDeviceToken.isEmpty) {
        return DeviceVerificationResult(
          isVerified: false,
          errorMessage: 'No device registered for this account',
        );
      }

      if (storedDeviceToken != currentDeviceToken) {
        return DeviceVerificationResult(
          isVerified: false,
          errorMessage:
              'Device not authorized. Please use your registered device.',
        );
      }

      // Check if student has already marked attendance
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final attendanceQuery = await _firestore
          .collection('Attendance')
          .where('sessionId', isEqualTo: sessionId)
          .where('email', isEqualTo: user.email!.toLowerCase())
          .where(
            'markedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('markedAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      if (attendanceQuery.docs.isNotEmpty) {
        final attendanceDoc = attendanceQuery.docs.first;
        final data = attendanceDoc.data();
        final status = data['status'];
        final revokedBy = data['revokedBy'];
        final revocationReason = data['revocationReason'];

        if (status == 'present') {
          return DeviceVerificationResult(
            isVerified: false,
            errorMessage:
                'You have already marked attendance for this session.',
          );
        } else if (status == 'absent' && revokedBy == 'teacher') {
          return DeviceVerificationResult(
            isVerified: false,
            errorMessage:
                'Your attendance was revoked by the teacher.\nReason: $revocationReason',
          );
        }
      }

      // Check if device has been used by another user
      final deviceAttendance = await _firestore
          .collection('Attendance')
          .where('sessionId', isEqualTo: sessionId)
          .where('deviceToken', isEqualTo: currentDeviceToken)
          .get();

      for (var doc in deviceAttendance.docs) {
        if (doc['email'] != user.email!.toLowerCase()) {
          return DeviceVerificationResult(
            isVerified: false,
            errorMessage:
                'This device has already been used to mark attendance for another account.',
          );
        }
      }

      // Device verified
      return DeviceVerificationResult(
        isVerified: true,
        shouldProceedToLocation: true,
      );
    } catch (e) {
      debugPrint('Device verification error: $e');
      return DeviceVerificationResult(
        isVerified: false,
        errorMessage: 'Verification failed: ${e.toString()}',
      );
    }
  }
}
