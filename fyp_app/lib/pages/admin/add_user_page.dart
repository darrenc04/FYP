import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AddUserPage extends StatefulWidget {
  final String? initialRole;
  const AddUserPage({super.key, this.initialRole});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();

  // Role selection
  String _role = 'student'; // Default
  String _program = '';

  // Sessions
  List<Map<String, dynamic>> _availableSessions = [];
  List<String> _selectedSessionIds = [];

  // Controller for the session search field
  final TextEditingController _sessionSearchController =
      TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRole != null) {
      _role = widget.initialRole!;
    }
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Sessions')
          .get();
      final sessions = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['sessionsName'] ?? doc.id,
          'code': data['courseCode'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _availableSessions = sessions;
        });
      }
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
    }
  }

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Role Selection (First)
              const Text(
                'Select Role',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _role,
                dropdownColor: const Color(0xFF4E585D),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Role'),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                ],
                onChanged: (val) {
                  setState(() {
                    _role = val!;
                    // Clear program if switching to teacher
                    if (_role == 'teacher') {
                      _program = '';
                    }
                  });
                },
              ),
              const SizedBox(height: 24),

              // 2. Common Fields
              _buildTextField(_nameController, 'Full Name'),
              const SizedBox(height: 16),
              _buildTextField(_emailController, 'Email', email: true),
              const SizedBox(height: 16),
              _buildTextField(_idController, 'ID Number'),
              const SizedBox(height: 16),
              _buildTextField(_phoneController, 'Phone Number'),
              const SizedBox(height: 16),

              // 3. Student Specific Fields
              if (_role == 'student') ...[
                _buildTextField(
                  TextEditingController(text: _program)
                    ..selection = TextSelection.fromPosition(
                      TextPosition(offset: _program.length),
                    ),
                  'Program',
                  onChanged: (val) => _program = val,
                ),
                const SizedBox(height: 16),
              ],

              // 4. Session Selection (Searchable Autocomplete + Chips)
              const Text(
                'Assign Sessions',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),

              // Autocomplete Field
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    // Show all sessions that aren't already selected
                    return _availableSessions.where(
                      (session) => !_selectedSessionIds.contains(session['id']),
                    );
                  }
                  return _availableSessions.where((session) {
                    final name = session['name'].toString().toLowerCase();
                    final code = session['code'].toString().toLowerCase();
                    final query = textEditingValue.text.toLowerCase();
                    final isSelected = _selectedSessionIds.contains(
                      session['id'],
                    );

                    return !isSelected &&
                        (name.contains(query) || code.contains(query));
                  });
                },
                displayStringForOption: (Map<String, dynamic> option) =>
                    option['name'],
                onSelected: (Map<String, dynamic> selection) {
                  setState(() {
                    _selectedSessionIds.add(selection['id']);
                    _sessionSearchController
                        .clear(); // Clear input after selection
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  // Keep our local controller in sync if needed, but mainly we want to clear it
                  if (_sessionSearchController.text != controller.text) {
                    // This might cause loops if not careful, but Autocomplete uses its own controller.
                    // We'll just use the passed controller for the UI.
                  }

                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Search to add session...')
                        .copyWith(
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white54,
                          ),
                          suffixIcon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white54,
                          ),
                        ),
                    onFieldSubmitted: (String value) {
                      onFieldSubmitted();
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      color: const Color(0xFF4E585D),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 40,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (option['code'] != '')
                                      Text(
                                        option['code'],
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Selected Sessions Chips
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _selectedSessionIds.map((id) {
                  final session = _availableSessions.firstWhere(
                    (s) => s['id'] == id,
                    orElse: () => {'name': 'Unknown Session', 'code': ''},
                  );
                  return Chip(
                    label: Text(
                      session['name'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: const Color(0xFF546E7A),
                    deleteIcon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.white70,
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedSessionIds.remove(id);
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // Submit Button
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

    FirebaseApp? secondaryApp;

    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _idController.text
          .trim(); // Default password is ID Number
      final fullName = _nameController.text.trim();
      final idNumber = _idController.text.trim();
      final phoneNumber = _phoneController.text.trim();

      // 1. Create User in Firebase Auth using a secondary app instance
      // This prevents the current admin from being logged out
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      UserCredential userCredential = await secondaryAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = userCredential.user?.uid;

      if (uid != null) {
        // 2. Create User Document in Firestore (using primary instance)
        await FirebaseFirestore.instance.collection('Users').doc(email).set({
          'uid': uid,
          'email': email,
          'fullName': fullName,
          'idNumber': idNumber,
          'phoneNumber': phoneNumber,
          'role': _role,
          'program': _role == 'student' ? _program : null,
          'sessionsId': _selectedSessionIds,
          'createdAt': FieldValue.serverTimestamp(),
          'deviceToken': '',
          'biometric': '',
          'profilePicture': '',
          // Student specific fields initialized
          if (_role == 'student') ...{
            'faceVerified': false,
            'fingerprintVerified': false,
            'lastDeviceRemoved': '',
          },
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User added successfully')),
          );
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Error creating user';
      if (e.code == 'email-already-in-use') {
        message = 'Email is already in use';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      // Clean up secondary app
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
      if (mounted) setState(() => _loading = false);
    }
  }
}
