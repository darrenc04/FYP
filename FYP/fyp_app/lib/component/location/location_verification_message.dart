import 'package:flutter/material.dart';

class LocationVerificationMessage extends StatelessWidget {
  final bool isVerifying;
  final bool isVerified;
  final bool isError;
  final String? errorMessage;
  final double? distance;

  const LocationVerificationMessage({
    super.key,
    required this.isVerifying,
    required this.isVerified,
    required this.isError,
    this.errorMessage,
    this.distance,
  });

  @override
  Widget build(BuildContext context) {
    if (isVerifying) {
      return Column(
        children: [
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
        ],
      );
    } else if (isVerified) {
      return Column(
        children: [
          const Text(
            'Location Verified!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (distance != null) ...[
            const SizedBox(height: 16),
            Text(
              'Distance: ${distance!.toStringAsFixed(1)}m',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ],
      );
    } else {
      return Column(
        children: [
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
            errorMessage ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      );
    }
  }
}
