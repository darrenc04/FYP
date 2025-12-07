import 'package:flutter/material.dart';
import '../controller/location_verification_controller.dart';
import '../model/location_verification_state.dart';
import '../component/location/location_status_icon.dart';
import '../component/location/location_verification_message.dart';

class LocationVerificationPage extends StatefulWidget {
  final String sessionId;
  final String sessionName;
  final double detectedFrequency;
  final double? faceConfidence;

  const LocationVerificationPage({
    super.key,
    required this.sessionId,
    required this.sessionName,
    required this.detectedFrequency,
    this.faceConfidence,
  });

  @override
  State<LocationVerificationPage> createState() =>
      _LocationVerificationPageState();
}

class _LocationVerificationPageState extends State<LocationVerificationPage> {
  final LocationVerificationController _controller =
      LocationVerificationController();
  LocationVerificationState _state = LocationVerificationState();

  @override
  void initState() {
    super.initState();
    _verifyLocation();
  }

  Future<void> _verifyLocation() async {
    try {
      // Get current location
      final currentLocation = await _controller.getCurrentLocation();

      // Get session location
      final sessionLocation = await _controller.getSessionLocation(
        widget.sessionId,
      );

      // Calculate distance
      double distance = _controller.calculateDistance(
        currentLocation.latitude!,
        currentLocation.longitude!,
        sessionLocation['latitude'],
        sessionLocation['longitude'],
      );

      setState(() {
        _state = _state.copyWith(distance: distance);
      });

      // Check if within boundary (50 meters)
      const double boundaryRadius = 50.0;

      if (!_controller.isWithinBoundary(
        distance,
        boundaryRadius: boundaryRadius,
      )) {
        setState(() {
          _state = _state.copyWith(
            verifying: false,
            errorMessage:
                'You are ${distance.toStringAsFixed(1)}m away from the class location.\nYou must be within ${boundaryRadius}m to mark attendance.',
          );
        });
        return;
      }

      // Location verified, save attendance
      final courseName = await _controller.saveAttendance(
        sessionId: widget.sessionId,
        location: currentLocation,
        distance: distance,
        detectedFrequency: widget.detectedFrequency,
        faceConfidence: widget.faceConfidence,
      );

      setState(() {
        _state = _state.copyWith(
          verifying: false,
          verified: true,
          courseName: courseName,
        );
      });

      // Wait to show success message
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() {
        _state = _state.copyWith(
          verifying: false,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      });
    }
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
            if (_state.courseName != null) Text('Course: ${_state.courseName}'),
            if (_state.distance != null) ...[
              const SizedBox(height: 8),
              Text(
                'Distance: ${_state.distance!.toStringAsFixed(1)}m from class',
              ),
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
              LocationStatusIcon(
                isVerifying: _state.isVerifying,
                isVerified: _state.isSuccess,
                isError: _state.isError,
              ),
              const SizedBox(height: 32),
              if (_state.isVerifying)
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              const SizedBox(height: 32),
              LocationVerificationMessage(
                isVerifying: _state.isVerifying,
                isVerified: _state.isSuccess,
                isError: _state.isError,
                errorMessage: _state.errorMessage,
                distance: _state.distance,
              ),
              if (_state.isError) ...[
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
