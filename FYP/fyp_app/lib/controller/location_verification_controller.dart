import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class LocationVerificationController {
  final Location _location = Location();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? '';
      }
    } catch (e) {
      debugPrint('Error getting device ID: $e');
    }
    return '';
  }

  Future<LocationData> getCurrentLocation() async {
    // Check if location service is enabled
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        throw Exception('Location service is disabled. Please enable GPS.');
      }
    }

    // Check location permission
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        throw Exception('Location permission denied');
      }
    }

    // Get current location
    LocationData currentLocation = await _location.getLocation();

    if (currentLocation.latitude == null || currentLocation.longitude == null) {
      throw Exception('Unable to get current location');
    }

    return currentLocation;
  }

  Future<Map<String, dynamic>> getSessionLocation(String sessionId) async {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Try to get specific session info for today
    final sessionSubDoc = await FirebaseFirestore.instance
        .collection('Sessions')
        .doc(sessionId)
        .collection(todayStr)
        .doc('session_info')
        .get();

    Map<String, dynamic>? sessionData;

    if (sessionSubDoc.exists) {
      sessionData = sessionSubDoc.data();
    } else {
      // Fallback to parent session document
      final sessionDoc = await FirebaseFirestore.instance
          .collection('Sessions')
          .doc(sessionId)
          .get();

      if (sessionDoc.exists) {
        sessionData = sessionDoc.data();
      }
    }

    if (sessionData == null) {
      throw Exception('Session not found');
    }

    // Retrieve location from GeoPoint
    if (sessionData['location'] is GeoPoint) {
      final GeoPoint geoPoint = sessionData['location'] as GeoPoint;
      return {'latitude': geoPoint.latitude, 'longitude': geoPoint.longitude};
    } else {
      throw Exception('Session location not configured (Missing GeoPoint)');
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  bool isWithinBoundary(double distance, {double boundaryRadius = 50.0}) {
    return distance <= boundaryRadius;
  }

  Future<String> saveAttendance({
    required String sessionId,
    required LocationData location,
    required double distance,
    required double detectedFrequency,
    double? faceConfidence,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      throw Exception('User not authenticated');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(user!.email!.toLowerCase())
        .get();

    if (!userDoc.exists) {
      throw Exception('User not found');
    }

    final userData = userDoc.data();
    final studentId = userData?['idNumber'] ?? '';
    final studentName = userData?['fullName'] ?? '';

    // Get device token
    final deviceToken = await getDeviceId();

    // Get session data for course information
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final sessionDoc = await FirebaseFirestore.instance
        .collection('Sessions')
        .doc(sessionId)
        .collection(todayStr)
        .doc('session_info')
        .get();

    final sessionData = sessionDoc.data();
    String courseName = sessionData?['sessionsName'] ?? 'Unknown';
    final startTime = sessionData?['start_time'] ?? 'Unknown';
    final endTime = sessionData?['end_time'] ?? 'Unknown';

    if (!sessionDoc.exists) {
      final parentDoc = await FirebaseFirestore.instance
          .collection('Sessions')
          .doc(sessionId)
          .get();
      courseName = parentDoc.data()?['sessionsName'] ?? 'Unknown';
    }

    // Check for existing attendance
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final existingAttendance = await FirebaseFirestore.instance
        .collection('Attendance')
        .where('sessionId', isEqualTo: sessionId)
        .where('email', isEqualTo: user.email!.toLowerCase())
        .where(
          'markedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('markedAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    if (existingAttendance.docs.isNotEmpty) {
      final doc = existingAttendance.docs.first;
      final data = doc.data();
      if (data['status'] == 'present') {
        debugPrint('Attendance already marked');
        return courseName;
      } else if (data['status'] == 'absent' && data['revokedBy'] == 'teacher') {
        throw Exception('Attendance revoked by teacher');
      }
    }

    // Determine verification method
    String verificationMethod = 'ultrasonic';
    if (faceConfidence != null && faceConfidence > 0) {
      verificationMethod = 'face';
    } else if (detectedFrequency == 0 && faceConfidence == null) {
      verificationMethod = 'fingerprint';
    }

    await FirebaseFirestore.instance.collection('Attendance').add({
      'studentId': studentId,
      'studentName': studentName,
      'email': user.email!.toLowerCase(),
      'sessionId': sessionId,
      'courseName': courseName,
      'markedAt': FieldValue.serverTimestamp(),
      'detectedFrequency': detectedFrequency,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'distance': distance,
      'status': 'present',
      'deviceToken': deviceToken,
      'faceConfidence': faceConfidence,
      'verificationMethod': verificationMethod,
      'startTime': startTime,
      'endTime': endTime,
    });

    debugPrint('Attendance saved successfully');
    return courseName;
  }
}
