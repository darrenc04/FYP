import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();
  String _role = 'student';
  String _program = '';
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3D4A4F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3D4A4F),
        elevation: 0,
        title: const Text('Add User', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_nameController, 'Full Name'),
              const SizedBox(height: 16),
              _buildTextField(_emailController, 'Email', email: true),
              const SizedBox(height: 16),
              _buildTextField(_idController, 'ID Number'),
              const SizedBox(height: 16),
              _buildTextField(_phoneController, 'Phone Number'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _role,
                dropdownColor: const Color(0xFF4E585D),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Role'),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                ],
                onChanged: (val) => setState(() => _role = val!),
              ),
              if (_role == 'student') ...[
                const SizedBox(height: 16),
                _buildTextField(
                  TextEditingController(text: _program)
                    ..selection = TextSelection.fromPosition(
                      TextPosition(offset: _program.length),
                    ),
                  'Program',
                  onChanged: (val) => _program = val,
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81C3D7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Add User',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF4E585D),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool email = false,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      onChanged: onChanged,
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final email = _emailController.text.trim().toLowerCase();
      await FirebaseFirestore.instance.collection('Users').doc(email).set({
        'fullName': _nameController.text.trim(),
        'email': email,
        'idNumber': _idController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'role': _role,
        'program': _role == 'student' ? _program : null,
        'createdAt': FieldValue.serverTimestamp(),
        'sessionsId': [],
        'deviceToken': '',
        'biometric': '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User added successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
