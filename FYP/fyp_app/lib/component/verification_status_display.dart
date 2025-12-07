import 'package:flutter/material.dart';

class VerificationStatusDisplay extends StatelessWidget {
  final bool isVerifying;
  final bool isVerified;
  final String? errorMessage;
  final VoidCallback? onGoBack;

  const VerificationStatusDisplay({
    super.key,
    required this.isVerifying,
    required this.isVerified,
    this.errorMessage,
    this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    if (isVerifying) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: 32),
          Text(
            'Verifying Device...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    if (isVerified) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.error_outline, size: 60, color: Colors.white),
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
          errorMessage ?? 'Unknown error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: onGoBack,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF49555B),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
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
    );
  }
}
