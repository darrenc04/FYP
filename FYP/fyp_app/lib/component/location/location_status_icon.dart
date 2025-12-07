import 'package:flutter/material.dart';

class LocationStatusIcon extends StatelessWidget {
  final bool isVerifying;
  final bool isVerified;
  final bool isError;

  const LocationStatusIcon({
    super.key,
    required this.isVerifying,
    required this.isVerified,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    if (isVerifying) {
      return const Icon(
        Icons.location_searching,
        size: 80,
        color: Colors.white,
      );
    } else if (isVerified) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.location_on, size: 60, color: Colors.white),
      );
    } else {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.location_off, size: 60, color: Colors.white),
      );
    }
  }
}
