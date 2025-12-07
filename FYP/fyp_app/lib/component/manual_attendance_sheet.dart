import 'package:flutter/material.dart';
import '../controller/manual_attendance_controller.dart';
import '../model/teacher_dashboard_data.dart';

/// Reusable manual attendance sheet component
class ManualAttendanceSheet extends StatefulWidget {
  final String sessionId;
  final String sessionName;
  final DateTime selectedDate;
  final VoidCallback onAttendanceChanged;

  const ManualAttendanceSheet({
    Key? key,
    required this.sessionId,
    required this.sessionName,
    required this.selectedDate,
    required this.onAttendanceChanged,
  }) : super(key: key);

  @override
  State<ManualAttendanceSheet> createState() => _ManualAttendanceSheetState();
}

class _ManualAttendanceSheetState extends State<ManualAttendanceSheet> {
  final ManualAttendanceController _controller = ManualAttendanceController();
  bool _loading = true;
  List<StudentAttendanceData> _students = [];
  List<StudentAttendanceData> _filteredStudents = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStudents() {
    final query = _searchController.text;
    setState(() {
      _filteredStudents = _controller.filterStudents(_students, query);
    });
  }

  Future<void> _fetchStudents() async {
    setState(() => _loading = true);
    try {
      final students = await _controller.fetchStudents(
        widget.sessionId,
        widget.selectedDate,
      );
      setState(() {
        _students = students;
        _filteredStudents = students;
        _loading = false;
      });
    } catch (e) {
      print("Error fetching students: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _markPresent(String studentEmail, String studentName) async {
    try {
      await _controller.markPresent(
        sessionId: widget.sessionId,
        sessionName: widget.sessionName,
        studentEmail: studentEmail,
        sessionDate: widget.selectedDate,
      );

      await _fetchStudents();
      widget.onAttendanceChanged();
    } catch (e) {
      print("Error marking present: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error marking attendance: $e')));
    }
  }

  Future<void> _revokeAttendance(
    String studentName,
    String attendanceDocId,
  ) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Untake Attendance for $studentName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please provide a reason or proof for revoking this attendance.',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason / Proof',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reason is required')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text(
                'Confirm',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true && attendanceDocId.isNotEmpty) {
      try {
        await _controller.revokeAttendance(
          attendanceDocId: attendanceDocId,
          reason: reasonController.text.trim(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revoked attendance for $studentName')),
        );
        _fetchStudents();
        widget.onAttendanceChanged();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error revoking attendance: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mark Attendance: ${widget.sessionName}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Search Bar
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name or ID number',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF546E7A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _filteredStudents.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'No students found'
                          : 'No matching students',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = _filteredStudents[index];

                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                student.name,
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (student.isRevoked)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red),
                                ),
                                child: const Text(
                                  'Revoked',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          student.idNumber,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: student.isPresent
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _revokeAttendance(
                                  student.name,
                                  student.attendanceDocId ?? '',
                                ),
                                child: const Text('Untake'),
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF81C3D7),
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () =>
                                    _markPresent(student.email, student.name),
                                child: const Text('Mark Present'),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
