import 'package:flutter/material.dart';

class DeviceBindingReminderBox extends StatelessWidget {
  const DeviceBindingReminderBox({super.key});

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
            children: const [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Reminder',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBulletPoint(
            'You can link your device to your account for secure attendance check-in.',
          ),
          _buildBulletPoint(
            'Each device is identified by its unique ID and must be registered before use.',
          ),
          _buildBulletPoint(
            'Only linked devices can be used for marking attendance.',
          ),
          _buildBulletPoint(
            'One device can only be linked to one user account at a time.',
            color: Colors.orange,
          ),
          _buildBulletPoint(
            'Security: Email verification is required for binding and unbinding.',
            color: Colors.blue,
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
