import 'package:flutter/material.dart';

/// Reusable profile header component with avatar and edit button
class ProfileHeader extends StatelessWidget {
  final String? profilePictureUrl;
  final VoidCallback onEditPressed;

  const ProfileHeader({
    Key? key,
    this.profilePictureUrl,
    required this.onEditPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage:
                profilePictureUrl != null && profilePictureUrl!.isNotEmpty
                ? NetworkImage(profilePictureUrl!)
                : null,
            backgroundColor: Colors.grey[300],
            child: profilePictureUrl == null || profilePictureUrl!.isEmpty
                ? const Icon(Icons.person, size: 50, color: Colors.grey)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: onEditPressed,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 16, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
