import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:math' as math;

class LocationVerificationPage extends StatefulWidget {
  final String sessionId;
  final String sessionName;
  final double detectedFrequency;

  const LocationVerificationPage({
    super.key,
    required this.sessionId,
    required this.sessionName,
    required this.detectedFrequency,
  });

  @override
  State<LocationVerificationPage> createState() =>
      _LocationVerificationPageState();
}

class _LocationVerificationPageState extends State<LocationVerificationPage> {
  bool _verifying = true;
  bool _verified = false;
  String? _errorMessage;
  double? _distance;
  final Location _location = Location();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  @override
  void initState() {
    super.initState();
    _verifyLocation();
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

  Future<void> _verifyLocation() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          setState(() {
            _verifying = false;
            _errorMessage = 'Location service is disabled. Please enable GPS.';
          });
          return;
        }
      }

      // Check location permission
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          setState(() {
            _verifying = false;
            _errorMessage = 'Location permission denied';
          });
          return;
        }
      }

      // Get current location
      LocationData currentLocation = await _location.getLocation();

      if (currentLocation.latitude == null ||
          currentLocation.longitude == null) {
        setState(() {
          _verifying = false;
          _errorMessage = 'Unable to get current location';
        });
        return;
      }

      // Get session location
      final sessionDoc = await FirebaseFirestore.instance
          .collection('Sessions')
          .doc(widget.sessionId)
          .get();

      if (!sessionDoc.exists) {
        setState(() {
          _verifying = false;
          _errorMessage = 'Session not found';
        });
        return;
      }

      final sessionData = sessionDoc.data();

      // Retrieve location from GeoPoint
      double sessionLat = 0.0;
      double sessionLon = 0.0;

      if (sessionData != null && sessionData['location'] is GeoPoint) {
        final GeoPoint geoPoint = sessionData['location'] as GeoPoint;
        sessionLat = geoPoint.latitude;
        sessionLon = geoPoint.longitude;
      } else {
        setState(() {
          _verifying = false;
          _errorMessage = 'Session location not configured (Missing GeoPoint)';
        });
        return;
      }

      // Calculate distance
      double distance = _calculateDistance(
        currentLocation.latitude!,
        currentLocation.longitude!,
        sessionLat,
        sessionLon,
      );

      setState(() {
        _distance = distance;
      });

      // Check if within boundary (50 meters)
      const double boundaryRadius = 50.0; // meters

      if (distance > boundaryRadius) {
        setState(() {
          _verifying = false;
          _errorMessage =
              'You are ${distance.toStringAsFixed(1)}m away from the class location.\nYou must be within ${boundaryRadius}m to mark attendance.';
        });
        return;
      }

      // Location verified, now save attendance
      await _saveAttendance(currentLocation);

      setState(() {
        _verifying = false;
        _verified = true;
      });

      // Wait to show success message
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('Location verification error: $e');
      setState(() {
        _verifying = false;
        _errorMessage = 'Failed to verify location: ${e.toString()}';
      });
    }
  }

  Future<void> _saveAttendance(LocationData location) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user!.email!.toLowerCase())
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data();
      final studentId = userData?['idNumber'] ?? '';
      final studentName = userData?['fullName'] ?? '';

      // Get device token
      final deviceToken = await _getDeviceId();

      // Create attendance record
      await FirebaseFirestore.instance
          .collection('Sessions')
          .doc(widget.sessionId)
          .collection('Attendance')
          .doc(user.email!.toLowerCase())
          .set({
            'studentId': studentId,
            'studentName': studentName,
            'email': user.email!.toLowerCase(),
            'timestamp': FieldValue.serverTimestamp(),
            'detectedFrequency': widget.detectedFrequency,
            'location': GeoPoint(location.latitude!, location.longitude!),
            'distance': _distance,
            'status': 'present',
            'deviceToken': deviceToken,
          });

      debugPrint('Attendance saved successfully');
    } catch (e) {
      debugPrint('Error saving attendance: $e');
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance marked successfully!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Session: ${widget.sessionName}'),
            const SizedBox(height: 8),
            Text(
              'Frequency: ${widget.detectedFrequency.toStringAsFixed(0)} Hz',
            ),
            if (_distance != null) ...[
              const SizedBox(height: 8),
              Text('Distance: ${_distance!.toStringAsFixed(1)}m from class'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Pop all routes until home and pass result to refresh
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text(
              'OK',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
          'Location Verification',
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
                const Icon(
                  Icons.location_searching,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 32),
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
                  'Verifying Location...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please wait while we check your location',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ] else if (_verified) ...[
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Location Verified!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_distance != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Distance: ${_distance!.toStringAsFixed(1)}m',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ] else ...[
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.location_off,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Location Verification Failed',
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
                  onPressed: () =>
                      Navigator.popUntil(context, (route) => route.isFirst),
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
