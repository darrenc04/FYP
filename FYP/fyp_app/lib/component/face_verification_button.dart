import 'package:flutter/material.dart';

class FaceVerificationButton extends StatelessWidget {
  final bool isVerifying;
  final int blinksDetected;
  final VoidCallback? onTap;

  const FaceVerificationButton({
    Key? key,
    required this.isVerifying,
    required this.blinksDetected,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isVerifying ? null : onTap,
      child: Column(
        children: [
          isVerifying
              ? const SizedBox(
                  width: 160,
                  height: 160,
                  child: Center(
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange,
                        ),
                      ),
                    ),
                  ),
                )
              : Icon(
                  Icons.videocam,
                  size: 160,
                  color: Colors.white.withOpacity(0.7),
                ),
          const SizedBox(height: 16),
          Text(
            isVerifying ? 'Verifying Face & Blinks...' : 'Tap to Record Video',
            style: TextStyle(
              fontSize: 16,
              color: isVerifying ? Colors.orange : Colors.grey.shade400,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (blinksDetected > 0)
            Text(
              'Blinks Detected: $blinksDetected',
              style: const TextStyle(fontSize: 14, color: Colors.green),
            ),
        ],
      ),
    );
  }
}
