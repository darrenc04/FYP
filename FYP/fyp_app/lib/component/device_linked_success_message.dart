import 'package:flutter/material.dart';

class DeviceLinkedSuccessMessage extends StatelessWidget {
  const DeviceLinkedSuccessMessage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        children: const [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Device successfully linked to your account ✓',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
