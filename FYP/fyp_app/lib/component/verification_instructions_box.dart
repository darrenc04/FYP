import 'package:flutter/material.dart';

class VerificationInstructionsBox extends StatelessWidget {
  const VerificationInstructionsBox({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
              const SizedBox(width: 8),
              Text(
                'Instructions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBulletPoint('Ensure good lighting and clear face visibility'),
          _buildBulletPoint('Face should be directly facing the camera'),
          _buildBulletPoint('Blink your eyes naturally at least 2 times'),
          _buildBulletPoint('Video duration: max 10 seconds'),
          _buildBulletPoint('Remove sunglasses or face obscurities'),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
