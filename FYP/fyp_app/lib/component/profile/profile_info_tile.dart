import 'package:flutter/material.dart';

/// Reusable profile information tile component
class ProfileInfoTile extends StatelessWidget {
  final String title;
  final String value;
  final bool isEditable;
  final String actionLabel;
  final VoidCallback? onActionPressed;

  const ProfileInfoTile({
    Key? key,
    required this.title,
    required this.value,
    this.isEditable = false,
    this.actionLabel = 'Edit',
    this.onActionPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
          if (isEditable && onActionPressed != null)
            TextButton(
              onPressed: onActionPressed,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
