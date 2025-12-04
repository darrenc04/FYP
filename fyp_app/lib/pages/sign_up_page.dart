// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/services.dart';
// import 'package:fyp_app/services/auth_service.dart';
// import 'home_page.dart';
// import 'login_page.dart';

// class SignUpPage extends StatefulWidget {
//   const SignUpPage({super.key});

//   @override
//   State<SignUpPage> createState() => _SignUpPageState();
// }

// class _SignUpPageState extends State<SignUpPage> {
//   final _emailController = TextEditingController();
//   final _phoneController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _fullNameController = TextEditingController();
//   final _idController = TextEditingController();
//   final _programController = TextEditingController();
//   bool _obscure = true;
//   bool _loading = false;
//   final AuthService _authService = AuthService();

//   @override
//   void dispose() {
//     _emailController.dispose();
//     _phoneController.dispose();
//     _passwordController.dispose();
//     _fullNameController.dispose();
//     _idController.dispose();
//     _programController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cardColor = const Color(0xFF4E585D);
//     return Scaffold(
//       backgroundColor: const Color(0xFF49555B),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Center(
//                 child: Column(
//                   children: [
//                     SizedBox(
//                       width: 92,
//                       height: 92,
//                       child: Image.asset(
//                         'assets/logo.png',
//                         fit: BoxFit.contain,
//                         errorBuilder: (context, error, stackTrace) => const FlutterLogo(size: 92),
//                       ),
//                     ),
//                     const SizedBox(height: 24),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 8),
//               const Text(
//                 'Create your new account',
//                 style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 6),
//               const Text(
//                 'Create an account for marking attendance easily',
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//               ),
//               const SizedBox(height: 18),
//               Container(
//                 padding: const EdgeInsets.all(14),
//                 decoration: BoxDecoration(
//                   color: cardColor,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Column(
//                   children: [
//                     TextField(
//                       controller: _fullNameController,
//                       keyboardType: TextInputType.name,
//                       style: const TextStyle(color: Colors.white),
//                       decoration: InputDecoration(
//                         hintText: 'Enter your full name',
//                         hintStyle: const TextStyle(color: Colors.white54),
//                         labelText: 'Full Name',
//                         labelStyle: const TextStyle(color: Colors.white70),
//                         filled: true,
//                         fillColor: Colors.transparent,
//                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     TextField(
//                       controller: _idController,
//                       keyboardType: TextInputType.text,
//                       style: const TextStyle(color: Colors.white),
//                       decoration: InputDecoration(
//                         hintText: 'Enter your Student / Staff ID',
//                         hintStyle: const TextStyle(color: Colors.white54),
//                         labelText: 'ID Number',
//                         labelStyle: const TextStyle(color: Colors.white70),
//                         filled: true,
//                         fillColor: Colors.transparent,
//                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     TextField(
//                       controller: _programController,
//                       keyboardType: TextInputType.text,
//                       style: const TextStyle(color: Colors.white),
//                       decoration: InputDecoration(
//                         hintText: 'Enter your program (e.g., CS, IT)',
//                         hintStyle: const TextStyle(color: Colors.white54),
//                         labelText: 'Program',
//                         labelStyle: const TextStyle(color: Colors.white70),
//                         filled: true,
//                         fillColor: Colors.transparent,
//                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     TextField(
//                       controller: _emailController,
//                       keyboardType: TextInputType.emailAddress,
//                       style: const TextStyle(color: Colors.white),
//                       decoration: InputDecoration(
//                         hintText: 'Enter your Email',
//                         hintStyle: const TextStyle(color: Colors.white54),
//                         labelText: 'Email Address',
//                         labelStyle: const TextStyle(color: Colors.white70),
//                         filled: true,
//                         fillColor: Colors.transparent,
//                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     TextField(
//                       controller: _phoneController,
//                       keyboardType: TextInputType.phone,
//                       style: const TextStyle(color: Colors.white),
//                       inputFormatters: [
//                         FilteringTextInputFormatter.digitsOnly,
//                       ],
//                       decoration: InputDecoration(
//                         hintText: 'Enter Mobile Number',
//                         hintStyle: const TextStyle(color: Colors.white54),
//                         labelText: 'Mobile Number',
//                         labelStyle: const TextStyle(color: Colors.white70),
//                         prefixText: '+60 ',
//                         prefixStyle: const TextStyle(color: Colors.white),
//                         filled: true,
//                         fillColor: Colors.transparent,
//                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     TextField(
//                       controller: _passwordController,
//                       obscureText: _obscure,
//                       style: const TextStyle(color: Colors.white),
//                       decoration: InputDecoration(
//                         hintText: 'Password',
//                         hintStyle: const TextStyle(color: Colors.white54),
//                         labelText: 'Password',
//                         labelStyle: const TextStyle(color: Colors.white70),
//                         suffixIcon: IconButton(
//                           icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
//                           onPressed: () => setState(() => _obscure = !_obscure),
//                         ),
//                         filled: true,
//                         fillColor: Colors.transparent,
//                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     SizedBox(
//                       width: double.infinity,
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.white,
//                           foregroundColor: Colors.black,
//                         ),
//                         onPressed: _loading
//                             ? null
//                             : () async {
//                                 if (_fullNameController.text.isEmpty ||
//                                     _idController.text.isEmpty ||
//                                     _programController.text.isEmpty ||
//                                     _emailController.text.isEmpty ||
//                                     _phoneController.text.isEmpty ||
//                                     _passwordController.text.isEmpty) {
//                                   ScaffoldMessenger.of(context).showSnackBar(
//                                     const SnackBar(content: Text('Please fill all fields')),
//                                   );
//                                   return;
//                                 }

//                                 if (_passwordController.text.length < 6) {
//                                   ScaffoldMessenger.of(context).showSnackBar(
//                                     const SnackBar(content: Text('Password must be at least 6 characters')),
//                                   );
//                                   return;
//                                 }

//                                 setState(() => _loading = true);
//                                 try {
//                                   final fullName = _fullNameController.text.trim();
//                                   final idNumber = _idController.text.trim();
//                                   final program = _programController.text.trim();
//                                   final email = _emailController.text.trim();
//                                   final password = _passwordController.text.trim();
//                                   final phoneNumber = _phoneController.text.trim();

//                                   // Create Firebase Auth user and save to Firestore with additional profile fields
//                                   final user = await _authService.registerWithEmail(
//                                     email,
//                                     password,
//                                     phoneNumber,
//                                     fullName,
//                                     idNumber,
//                                     program,
//                                   );

//                                   if (user != null) {
//                                     await FirebaseAuth.instance.signOut();
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       const SnackBar(content: Text('Account created successfully! Please sign in.')),
//                                     );
//                                     Navigator.of(context).pushReplacementNamed('/login');
//                                   }
//                                 } on FirebaseAuthException catch (e) {
//                                   ScaffoldMessenger.of(context).showSnackBar(
//                                     SnackBar(content: Text(e.message ?? 'An error occurred')),
//                                   );
//                                 } catch (e) {
//                                   ScaffoldMessenger.of(context).showSnackBar(
//                                     SnackBar(content: Text(e.toString())),
//                                   );
//                                 } finally {
//                                   if (mounted) setState(() => _loading = false);
//                                 }
//                               },
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                           child: _loading
//                               ? const SizedBox(
//                                   width: 20,
//                                   height: 20,
//                                   child: CircularProgressIndicator(strokeWidth: 2),
//                                 )
//                               : const Text('Register'),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 14),
//               Center(child: Text('or register using', style: TextStyle(color: Colors.white70))),
//               const SizedBox(height: 12),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   IconButton(
//                     onPressed: _loading
//                         ? null
//                         : () async {
//                             setState(() => _loading = true);
//                             try {
//                               final user = await _authService.signInWithGoogle();
//                               if (user != null) {
//                                 Navigator.of(context)
//                                     .pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
//                               }
//                             } on MissingPluginException catch (_) {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 const SnackBar(
//                                   content: Text(
//                                       'Google Sign-In is not available on this platform or the plugin was not registered. Try a full restart: flutter clean; flutter pub get; flutter run.'),
//                                 ),
//                               );
//                             } catch (e) {
//                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
//                             } finally {
//                               if (mounted) setState(() => _loading = false);
//                             }
//                           },
//                     icon: Image.asset('assets/google.png',
//                         width: 36,
//                         height: 36,
//                         errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 30)),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               Center(
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Text('Already Registered? ', style: TextStyle(color: Colors.white70)),
//                     TextButton(
//                       onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
//                       child: const Text('Sign In'),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
