import 'package:flutter/material.dart';
import '../model/attendance_record.dart';
import '../controller/attendance_history_controller.dart';
import '../component/attendance_history_card.dart';

class AttendanceHistoryPage extends StatefulWidget {
  final String? selectedCourse;

  const AttendanceHistoryPage({super.key, this.selectedCourse});

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  final AttendanceHistoryController _controller = AttendanceHistoryController();
  late Future<List<AttendanceRecord>> _attendanceRecords;
  String _filterCourse = 'All';

  @override
  void initState() {
    super.initState();
    // Set the filter to the selected course if provided
    if (widget.selectedCourse != null) {
      _filterCourse = widget.selectedCourse!;
    }
    _attendanceRecords = _controller.fetchAttendanceHistory(_filterCourse);
  }

  void _refreshAttendance() {
    setState(() {
      _attendanceRecords = _controller.fetchAttendanceHistory(_filterCourse);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3D4A4F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3D4A4F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Attendance History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: Column(
        children: [
          // Attendance list
          Expanded(
            child: FutureBuilder<List<AttendanceRecord>>(
              future: _attendanceRecords,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading attendance: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final records = snapshot.data ?? [];

                if (records.isEmpty) {
                  return Center(
                    child: Text(
                      _filterCourse == 'All'
                          ? 'No attendance records found'
                          : 'No attendance records for this course',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => Future(() => _refreshAttendance()),
                  color: const Color(0xFF4A9FE8),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      return AttendanceHistoryCard(record: records[index]);
                    },
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
