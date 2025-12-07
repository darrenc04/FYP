import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final String userRole;
  final String? profilePicture;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onTestDataTap;

  const HomeHeader({
    Key? key,
    required this.userName,
    required this.userRole,
    this.profilePicture,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onTestDataTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onProfileTap,
          child: CircleAvatar(
            radius: 20,
            backgroundImage:
                profilePicture != null && profilePicture!.isNotEmpty
                ? NetworkImage(profilePicture!)
                : null,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: profilePicture == null || profilePicture!.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 24)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                userRole == 'teacher' ? 'Teacher' : 'Student',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onSettingsTap,
            padding: EdgeInsets.zero,
            iconSize: 20,
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF3D4A4F)),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.orange[300],
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onTestDataTap,
            padding: EdgeInsets.zero,
            iconSize: 20,
            icon: const Icon(Icons.storage, color: Color(0xFF3D4A4F)),
            tooltip: 'Insert Test Data',
          ),
        ),
      ],
    );
  }
}
