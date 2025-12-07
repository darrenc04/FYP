import 'package:flutter/material.dart';
import '../controller/forgot_password_controller.dart';
import '../component/password_reset_form.dart';
import '../component/forgot_password_header.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final ForgotPasswordController _controller = ForgotPasswordController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    setState(() => _loading = true);

    final result = await _controller.sendPasswordResetEmail(
      _emailController.text,
    );

    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent! Check your email.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else if (result.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ForgotPasswordHeader(),
              const SizedBox(height: 24),
              PasswordResetForm(
                emailController: _emailController,
                isLoading: _loading,
                onSendResetLink: _sendResetLink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
