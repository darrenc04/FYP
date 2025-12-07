import 'package:flutter/material.dart';

class FingerprintScanButton extends StatelessWidget {
  final bool isRegistered;
  final bool isVerifying;
  final VoidCallback? onTap;

  const FingerprintScanButton({
    Key? key,
    required this.isRegistered,
    required this.isVerifying,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Verify Your Fingerprint',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: isRegistered && !isVerifying ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRegistered && !isVerifying
                  ? Colors.blueGrey.shade700
                  : Colors.grey.shade700,
              border: Border.all(
                color: isVerifying ? Colors.orange : Colors.white,
                width: isVerifying ? 4 : 2,
              ),
            ),
            child: const Icon(Icons.fingerprint, size: 64, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
