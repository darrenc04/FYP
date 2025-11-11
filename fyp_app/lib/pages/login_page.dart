import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = const Color(0xFF4E585D);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const FlutterLogo(size: 92),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to your account',
                style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in to access your school profile.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter your Email',
                        hintStyle: const TextStyle(color: Colors.white54),
                        labelText: 'Email Address',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: const TextStyle(color: Colors.white54),
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Colors.white70),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('Forgot password?', style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                        onPressed: () {
                          // TODO: hook into real auth
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Sign In'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(child: Text('or sign in using', style: TextStyle(color: Colors.white70))),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: Image.asset('assets/google.png', width: 36, height: 36, errorBuilder: (c,e,s) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 30)),
                  ),
                  const SizedBox(width: 18),
                  IconButton(
                    onPressed: () {},
                    icon: Image.asset('assets/apple.png', width: 36, height: 36, errorBuilder: (c,e,s) => const Icon(Icons.apple, color: Colors.white, size: 30)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Don't have an account, ", style: TextStyle(color: Colors.white70)),
                    TextButton(onPressed: () {}, child: const Text('Sign up')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
