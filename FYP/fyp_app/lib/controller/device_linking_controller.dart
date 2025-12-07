import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:math';
import '../model/device_linking.dart';
import '../services/email_service.dart';

class DeviceLinkingController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<DeviceLinking> loadDeviceLinkingData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return DeviceLinking(
          isEnabled: false,
          currentDeviceId: '',
          linkedDeviceId: '',
        );
      }

      // Get current device ID
      final currentDeviceId = await _getDeviceId();

      // Load user's device linking data
      final docId = user.email!.toLowerCase();
      final doc = await _firestore.collection('Users').doc(docId).get();

      if (doc.exists) {
        final data = doc.data();
        final deviceToken = data?['deviceToken'] ?? '';

        // Safely handle lastDeviceRemoved which might be a String or Timestamp
        final lastRemovedRaw = data?['lastDeviceRemoved'];

        if (lastRemovedRaw is Timestamp) {
          // Handle Timestamp type
        } else if (lastRemovedRaw is String && lastRemovedRaw.isNotEmpty) {
          // If it's a string, try to parse it or ignore it
          try {
            // Parse if needed
          } catch (_) {
            // Ignore invalid date strings
          }
        }

        return DeviceLinking(
          isEnabled: deviceToken.isNotEmpty,
          currentDeviceId: currentDeviceId,
          linkedDeviceId: deviceToken,
        );
      }

      return DeviceLinking(
        isEnabled: false,
        currentDeviceId: currentDeviceId,
        linkedDeviceId: '',
      );
    } catch (e) {
      debugPrint('Error loading device linking: $e');
      return DeviceLinking(
        isEnabled: false,
        currentDeviceId: '',
        linkedDeviceId: '',
      );
    }
  }

  Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id; // Unique Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? '';
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        return windowsInfo.deviceId;
      }
    } catch (e) {
      debugPrint('Error getting device ID: $e');
    }
    return '';
  }

  Future<bool> verifyWithEmail(String userEmail, String action) async {
    // Generate Code
    final code = (Random().nextInt(900000) + 100000).toString();

    // Send Email
    final sent = await EmailService.sendVerificationCode(userEmail, code);

    if (!sent) {
      return false;
    }

    return true;
  }

  String generateVerificationCode() {
    return (Random().nextInt(900000) + 100000).toString();
  }

  Future<bool> sendVerificationEmail(String email, String code) async {
    return await EmailService.sendVerificationCode(email, code);
  }

  Future<bool> checkDeviceAlreadyLinked(String deviceId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final docId = user.email!.toLowerCase();

    final querySnapshot = await _firestore
        .collection('Users')
        .where('deviceToken', isEqualTo: deviceId)
        .get();

    // Filter out the current user's doc
    final otherUsers = querySnapshot.docs.where((doc) => doc.id != docId);

    return otherUsers.isNotEmpty;
  }

  Future<void> bindDevice(String deviceId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docId = user.email!.toLowerCase();
    await _firestore.collection('Users').doc(docId).update({
      'deviceToken': deviceId,
    });
  }

  Future<void> unbindDevice() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docId = user.email!.toLowerCase();
    await _firestore.collection('Users').doc(docId).update({
      'deviceToken': '',
      'lastDeviceRemoved': FieldValue.serverTimestamp(),
    });
  }
}
