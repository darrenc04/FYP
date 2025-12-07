import 'package:flutter/material.dart';

class SocialLoginButton extends StatelessWidget {
  final VoidCallback onGoogleSignIn;
  final bool isLoading;

  const SocialLoginButton({
    super.key,
    required this.onGoogleSignIn,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Center(
          child: Text(
            'or sign in using',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: isLoading ? null : onGoogleSignIn,
              icon: Image.asset(
                'assets/google.png',
                width: 36,
                height: 36,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.g_mobiledata,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(width: 18),
          ],
        ),
      ],
    );
  }
}
