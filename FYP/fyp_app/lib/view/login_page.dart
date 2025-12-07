import 'package:flutter/material.dart';
import '../controller/login_controller.dart';
import '../component/login/login_header.dart';
import '../component/login/login_form_card.dart';
import '../component/social_login_button.dart';
import 'home_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final LoginController _controller = LoginController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_controller.isValidInput(
      _emailController.text,
      _passwordController.text,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Check for admin credentials
      if (_controller.isAdminCredentials(email, password)) {
        Navigator.of(context).pushReplacementNamed('/admin-dashboard');
        return;
      }

      // Sign in with email
      final result = await _controller.signInWithEmail(email, password);

      if (result.success) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage ?? 'Login failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);

    try {
      final result = await _controller.signInWithGoogle();

      if (result.success) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Google sign-in failed'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LoginHeader(),
              const SizedBox(height: 18),
              LoginFormCard(
                emailController: _emailController,
                passwordController: _passwordController,
                obscurePassword: _obscure,
                onTogglePasswordVisibility: () {
                  setState(() => _obscure = !_obscure);
                },
                onForgotPassword: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordPage(),
                    ),
                  );
                },
                onSignIn: _handleSignIn,
                isLoading: _loading,
              ),
              const SizedBox(height: 14),
              SocialLoginButton(
                onGoogleSignIn: _handleGoogleSignIn,
                isLoading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
