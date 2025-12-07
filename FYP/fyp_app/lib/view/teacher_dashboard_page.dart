import 'package:flutter/material.dart';
import '../controller/teacher_dashboard_controller.dart';
import '../model/teacher_dashboard_data.dart';
import '../component/dashboard_date_selector.dart';
import '../component/total_sessions_card.dart';
import '../component/session_list_item.dart';
import '../component/manual_attendance_sheet.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  final TeacherDashboardController _controller = TeacherDashboardController();
  bool _loading = true;
  TeacherDashboardData? _dashboardData;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadPublicHolidays();
    _fetchDashboardData();
  }

  Future<void> _loadPublicHolidays() async {
    await _controller.loadPublicHolidays();
    _fetchDashboardData();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _loading = true;
      });
      _fetchDashboardData();
    }
  }

  Future<void> _fetchDashboardData() async {
    final data = await _controller.fetchDashboardData(_selectedDate);
    if (mounted) {
      setState(() {
        _dashboardData = data;
        _loading = false;
      });
    }
  }

  Future<void> _showManualAttendanceDialog(SessionStat sessionStat) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF3D4A4F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ManualAttendanceSheet(
          sessionId: sessionStat.sessionId,
          sessionName: sessionStat.name,
          selectedDate: _selectedDate,
          onAttendanceChanged: _fetchDashboardData,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF3D4A4F),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final data = _dashboardData;
    if (data == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF3D4A4F),
        body: Center(
          child: Text(
            'Error loading dashboard',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

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
          'Lecturer Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardDateSelector(
              selectedDate: _selectedDate,
              onDateTap: () => _selectDate(context),
            ),
            const SizedBox(height: 30),
            TotalSessionsCard(totalSessions: data.totalSessions),
            const SizedBox(height: 40),
            const Text(
              'My Sessions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (data.isHolidayDate)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(Icons.celebration, color: Colors.white54, size: 64),
                      SizedBox(height: 16),
                      Text(
                        'No classes for today',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Public Holiday',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else if (data.sessionStats.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        color: Colors.white54,
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No sessions available',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.sessionStats.length,
                itemBuilder: (context, index) {
                  final stat = data.sessionStats[index];
                  return SessionListItem(
                    sessionStat: stat,
                    onTap: () => _showManualAttendanceDialog(stat),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
