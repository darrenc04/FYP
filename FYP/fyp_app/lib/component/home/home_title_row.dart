import 'package:flutter/material.dart';

class HomeTitleRow extends StatelessWidget {
  final String userRole;
  final VoidCallback? onDashboardTap;
  final VoidCallback? onHistoryTap;

  const HomeTitleRow({
    Key? key,
    required this.userRole,
    this.onDashboardTap,
    this.onHistoryTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "Today's classes",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (userRole == 'teacher')
          Container(
            margin: const EdgeInsets.only(right: 10),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF81C3D7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: onDashboardTap,
              padding: EdgeInsets.zero,
              iconSize: 20,
              icon: const Icon(
                Icons.dashboard_outlined,
                color: Color(0xFF3D4A4F),
              ),
            ),
          ),
        if (userRole == 'student')
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: onHistoryTap,
              padding: EdgeInsets.zero,
              iconSize: 20,
              icon: const Icon(Icons.history, color: Color(0xFF3D4A4F)),
            ),
          ),
      ],
    );
  }
}
