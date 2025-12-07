import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddEditSessionPage extends StatefulWidget {
  final Map<String, dynamic>? sessionData; // If null, it's Add mode
  final String? sessionId; // Document ID (Course Code)

  const AddEditSessionPage({super.key, this.sessionData, this.sessionId});

  @override
  State<AddEditSessionPage> createState() => _AddEditSessionPageState();
}

class _AddEditSessionPageState extends State<AddEditSessionPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _courseCodeController;
  late TextEditingController _sessionNameController;
  late TextEditingController _lecturerNameController;
  late TextEditingController _physicalLocationController;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  // State variables
  String? _selectedSessionType;
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isCancelled = false;
  bool _loading = false;
  bool _isEditMode = false;

  List<String> _teacherNames = [];
  final List<String> _sessionTypes = ['Lecture', 'Tutorial', 'Practical'];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.sessionData != null;

    // Initialize controllers
    _courseCodeController = TextEditingController(text: widget.sessionId ?? '');
    _sessionNameController = TextEditingController(
      text: widget.sessionData?['sessionsName'] ?? '',
    );
    _lecturerNameController = TextEditingController(
      text: widget.sessionData?['lecturerName'] ?? '',
    );
    _physicalLocationController = TextEditingController(
      text: widget.sessionData?['physicalLocation'] ?? '',
    );

    // Initialize Session Type
    if (widget.sessionData != null) {
      _selectedSessionType = widget.sessionData?['sessionsType'];
      // Validate that the loaded type exists in our list
      if (_selectedSessionType != null &&
          !_sessionTypes.contains(_selectedSessionType)) {
        _selectedSessionType = null;
      }
    }

    // Handle Location (GeoPoint)
    double lat = 0;
    double lng = 0;
    if (widget.sessionData != null &&
        widget.sessionData!['location'] is GeoPoint) {
      final GeoPoint gp = widget.sessionData!['location'];
      lat = gp.latitude;
      lng = gp.longitude;
    }
    _latController = TextEditingController(
      text: _isEditMode ? lat.toString() : '',
    );
    _lngController = TextEditingController(
      text: _isEditMode ? lng.toString() : '',
    );

    // Handle Times (Timestamp)
    if (widget.sessionData != null) {
      if (widget.sessionData!['start_time'] is Timestamp) {
        _startTime = (widget.sessionData!['start_time'] as Timestamp).toDate();
      }
      if (widget.sessionData!['end_time'] is Timestamp) {
        _endTime = (widget.sessionData!['end_time'] as Timestamp).toDate();
      }
      _isCancelled = widget.sessionData!['isCancelled'] ?? false;
    }

    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('role', isEqualTo: 'teacher')
          .get();

      if (mounted) {
        setState(() {
          _teacherNames = snapshot.docs
              .map((doc) => doc['fullName'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
        });
        debugPrint('Fetched ${_teacherNames.length} teachers');
      }
    } catch (e) {
      debugPrint('Error fetching teachers: $e');
    }
  }

  @override
  void dispose() {
    _courseCodeController.dispose();
    _sessionNameController.dispose();
    _lecturerNameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3D4A4F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3D4A4F),
        elevation: 0,
        title: Text(
          _isEditMode ? 'Edit Session' : 'Add Session',
          style: const TextStyle(color: Colors.white),
        ),
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
              // Course Code (ID)
              _buildTextField(
                _courseCodeController,
                'Course Code (ID)',
                enabled: !_isEditMode,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                _sessionNameController,
                'Session Name',
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Lecturer Name Searchable Dropdown
              Autocomplete<String>(
                initialValue: TextEditingValue(
                  text: _lecturerNameController.text,
                ),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  // If empty, show all options (like a dropdown)
                  if (textEditingValue.text == '') {
                    return _teacherNames;
                  }
                  return _teacherNames.where((String option) {
                    return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },
                onSelected: (String selection) {
                  _lecturerNameController.text = selection;
                },
                fieldViewBuilder:
                    (
                      context,
                      textEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      // Sync controller if needed (carefully)
                      if (textEditingController.text.isEmpty &&
                          _lecturerNameController.text.isNotEmpty) {
                        textEditingController.text =
                            _lecturerNameController.text;
                      }

                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onChanged: (val) => _lecturerNameController.text = val,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Lecturer Name',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF4E585D),
                          // Dropdown arrow to indicate it's a list
                          suffixIcon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                          // Search icon to indicate it's searchable
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white70,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      color: const Color(0xFF4E585D),
                      child: SizedBox(
                        width:
                            MediaQuery.of(context).size.width -
                            40, // Match width of field
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  option,
                                  style: const TextStyle(color: Colors.white),
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
              const SizedBox(height: 16),

              // Session Type Dropdown
              DropdownButtonFormField<String>(
                value: _selectedSessionType,
                dropdownColor: const Color(0xFF4E585D),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Session Type',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF4E585D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                ),
                items: _sessionTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (val) => setState(() => _selectedSessionType = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Date & Time Pickers
              Row(
                children: [
                  Expanded(
                    child: _buildDateTimePicker(
                      'Start Time',
                      _startTime,
                      (picked) => setState(() => _startTime = picked),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDateTimePicker(
                      'End Time',
                      _endTime,
                      (picked) => setState(() => _endTime = picked),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _latController,
                      'Latitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      _lngController,
                      'Longitude',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Physical Location - Enhanced Design
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4E585D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF81C3D7).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: TextFormField(
                  controller: _physicalLocationController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Physical Location',
                    labelStyle: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    hintText: 'e.g., DK1, Lab A, Room 101',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 13,
                    ),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF81C3D7).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFF81C3D7),
                        size: 20,
                      ),
                    ),
                    suffixIcon: _physicalLocationController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _physicalLocationController.clear();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF81C3D7),
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.redAccent,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 16),

              // Cancelled Switch
              SwitchListTile(
                title: const Text(
                  'Is Cancelled?',
                  style: TextStyle(color: Colors.white),
                ),
                value: _isCancelled,
                activeColor: const Color(0xFF81C3D7),
                onChanged: (val) => setState(() => _isCancelled = val),
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
                      : Text(
                          _isEditMode ? 'Save Changes' : 'Create Session',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
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

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(color: enabled ? Colors.white : Colors.white54),
      validator: validator,
      decoration: InputDecoration(
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
      ),
    );
  }

  Widget _buildDateTimePicker(
    String label,
    DateTime? selectedDate,
    Function(DateTime) onPicked,
  ) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF81C3D7),
                  onPrimary: Colors.black,
                  surface: Color(0xFF3D4A4F),
                  onSurface: Colors.white,
                ),
                dialogBackgroundColor: const Color(0xFF3D4A4F),
              ),
              child: child!,
            );
          },
        );
        if (date == null) return;

        if (!mounted) return;

        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(selectedDate ?? DateTime.now()),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF81C3D7),
                  onPrimary: Colors.black,
                  surface: Color(0xFF3D4A4F),
                  onSurface: Colors.white,
                ),
                dialogBackgroundColor: const Color(0xFF3D4A4F),
              ),
              child: child!,
            );
          },
        );
        if (time == null) return;

        onPicked(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF4E585D),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
        ),
        child: Text(
          selectedDate != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(selectedDate)
              : 'Select Date & Time',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end times')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final courseCode = _courseCodeController.text.trim();
      final lat = double.tryParse(_latController.text.trim()) ?? 0.0;
      final lng = double.tryParse(_lngController.text.trim()) ?? 0.0;

      final data = {
        'courseCode': courseCode,
        'sessionsName': _sessionNameController.text.trim(),
        'lecturerName': _lecturerNameController.text.trim(),
        'sessionsType': _selectedSessionType,
        'start_time': Timestamp.fromDate(_startTime!),
        'end_time': Timestamp.fromDate(_endTime!),
        'location': GeoPoint(lat, lng),
        'isCancelled': _isCancelled,
        'physicalLocation': _physicalLocationController.text.trim(),
      };

      if (_isEditMode) {
        // Update existing
        await FirebaseFirestore.instance
            .collection('Sessions')
            .doc(widget.sessionId)
            .update(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session updated successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        // Create new
        // Check if ID already exists
        final doc = await FirebaseFirestore.instance
            .collection('Sessions')
            .doc(courseCode)
            .get();

        if (doc.exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session ID (Course Code) already exists'),
              ),
            );
          }
          setState(() => _loading = false);
          return;
        }

        await FirebaseFirestore.instance
            .collection('Sessions')
            .doc(courseCode)
            .set(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session created successfully')),
          );
          Navigator.pop(context);
        }
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
