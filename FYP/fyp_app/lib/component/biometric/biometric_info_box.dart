import 'package:flutter/material.dart';

class BiometricInfoBox extends StatelessWidget {
  final bool isMockMode;

  const BiometricInfoBox({super.key, required this.isMockMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: isMockMode ? Colors.purple : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isMockMode ? 'Mock Mode Testing' : 'Using DeepFace',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isMockMode) ...[
            _buildBulletPoint(
              '⚠️ MOCK MODE: Biometric capability simulation for testing without real biometrics.',
              color: Colors.purple.shade700,
            ),
            _buildBulletPoint(
              'Face registration and verification are simulated. Set _isMockMode = false to use real DeepFace.',
              color: Colors.purple.shade700,
            ),
          ],
          if (!isMockMode) ...[
            _buildBulletPoint('Enable Device Biometric to register your face.'),
            _buildBulletPoint(
              'Your face will be verified using DeepFace technology.',
              color: Colors.blue.shade700,
            ),
          ],
          _buildBulletPoint(
            'Tap "Register Face" to capture and register your face image.',
          ),
          _buildBulletPoint(
            'On subsequent logins, your face will be automatically verified.',
          ),
          _buildBulletPoint(
            'Ensure good lighting and clear face visibility for best results.',
          ),
          if (!isMockMode)
            _buildBulletPoint(
              'Make sure DeepFace backend server is running on your machine.',
            ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text, {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 16, color: color)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: color, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
