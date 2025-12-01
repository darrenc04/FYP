import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditUserPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditUserPage({super.key, required this.userData});

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _idController;
  late TextEditingController _phoneController;
  late TextEditingController _programController;

  // Controller for the session search field
  final TextEditingController _sessionSearchController =
      TextEditingController();

  // Role selection (Read-only)
  late String _role;

  // Sessions
  List<Map<String, dynamic>> _availableSessions = [];
  List<String> _selectedSessionIds = [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.userData;
    _nameController = TextEditingController(text: data['fullName']);
    _emailController = TextEditingController(text: data['email']);
    _idController = TextEditingController(text: data['idNumber']);
    _phoneController = TextEditingController(text: data['phoneNumber']);
    _programController = TextEditingController(text: data['program'] ?? '');

    _role = data['role'] ?? 'student';
    _selectedSessionIds = List<String>.from(data['sessionsId'] ?? []);

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
        title: const Text('Edit User', style: TextStyle(color: Colors.white)),
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
              // 1. Role (Read-only)
              _buildReadOnlyField('Role', _role.toUpperCase()),
              const SizedBox(height: 16),

              // 2. Email (Read-only)
              _buildReadOnlyField('Email', _emailController.text),
              const SizedBox(height: 24),

              // 3. Editable Fields
              _buildTextField(_nameController, 'Full Name'),
              const SizedBox(height: 16),
              _buildTextField(_idController, 'ID Number'),
              const SizedBox(height: 16),
              _buildTextField(_phoneController, 'Phone Number'),
              const SizedBox(height: 16),

              // 4. Student Specific Fields
              if (_role == 'student') ...[
                _buildTextField(_programController, 'Program'),
                const SizedBox(height: 16),
              ],

              // 5. Session Selection (Searchable Autocomplete + Chips)
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
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      if (_sessionSearchController.text != controller.text) {
                        // Sync logic if needed
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
                          'Save Changes',
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
      onChanged: onChanged,
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return TextFormField(
      initialValue: value,
      style: const TextStyle(color: Colors.white54),
      decoration: _inputDecoration(label),
      readOnly: true,
      enabled: false,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();

      Map<String, dynamic> updates = {
        'fullName': _nameController.text.trim(),
        'idNumber': _idController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'sessionsId': _selectedSessionIds,
      };

      if (_role == 'student') {
        updates['program'] = _programController.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(email)
          .update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully')),
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
