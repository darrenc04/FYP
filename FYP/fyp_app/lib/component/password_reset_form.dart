import 'package:flutter/material.dart';

class PasswordResetForm extends StatelessWidget {
  final TextEditingController emailController;
  final bool isLoading;
  final VoidCallback onSendResetLink;

  const PasswordResetForm({
    Key? key,
    required this.emailController,
    required this.isLoading,
    required this.onSendResetLink,
  }) : super(key: key);

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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              onPressed: isLoading ? null : onSendResetLink,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Reset Link'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
