import 'package:flutter/material.dart';

class LoginFormCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onForgotPassword;
  final VoidCallback onSignIn;
  final bool isLoading;

  const LoginFormCard({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePasswordVisibility,
    required this.onForgotPassword,
    required this.onSignIn,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = const Color(0xFF4E585D);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your Email',
              hintStyle: const TextStyle(color: Colors.white54),
              labelText: 'Email Address',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: const TextStyle(color: Colors.white54),
              labelText: 'Password',
              labelStyle: const TextStyle(color: Colors.white70),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: onTogglePasswordVisibility,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onForgotPassword,
              child: const Text(
                'Forgot password?',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              onPressed: isLoading ? null : onSignIn,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign In'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
