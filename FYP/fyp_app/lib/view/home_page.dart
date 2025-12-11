import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyp_app/view/profile_page.dart';
import '../controller/home_controller.dart';
import '../model/home_user_data.dart';
import '../model/session_data.dart';
import '../component/home/home_header.dart';
import '../component/home/home_title_row.dart';
import '../component/student_session_card.dart';
import '../component/teacher_session_card.dart';
import 'attendance_overview_page.dart';
import 'teacher_dashboard_page.dart';
import 'ultrasonic_page.dart';
import 'face_verification_page.dart';
import 'fingerprint_verification_page.dart';
import 'timetable_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final HomeController _controller = HomeController();

  HomeUserData? _userData;
  List<SessionData> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == true) {
      _refreshData();
    }
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _refreshData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final holidays = await _controller.loadPublicHolidays();
    if (mounted) {
      _controller.publicHolidays = holidays;
    }

    final userData = await _controller.fetchUserData();
    if (mounted && userData != null) {
      _userData = userData;
      final sessions = await _controller.fetchSessions(userData.role);
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _loading = true;
      _sessions = [];
    });
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF3D4A4F);
    final userName = _userData?.name ?? 'User';
    final userRole = _userData?.role ?? 'student';
    final profilePicture = _userData?.profilePicture;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeHeader(
                userName: userName,
                userRole: userRole,
                profilePicture: profilePicture,
                onProfileTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  );
                },
                onSettingsTap: () {
                  Navigator.pushNamed(context, '/settings');
                },
                // onTestDataTap: () {
                //   Navigator.push(
                //     context,
                //     MaterialPageRoute(
                //       builder: (context) => const InsertTestDataPage(),
                //     ),
                //   );
                // },
              ),
              const SizedBox(height: 28),
              HomeTitleRow(
                userRole: userRole,
                onDashboardTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TeacherDashboardPage(),
                    ),
                  );
                },
                onHistoryTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AttendanceOverviewPage(),
                    ),
                  );
                },
                onTimetableTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TimetablePage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : _sessions.isEmpty
                    ? const Center(
                        child: Text(
                          'No sessions assigned',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshData,
                        color: const Color(0xFF4A9FE8),
                        child: ListView.builder(
                          itemCount: _sessions.length,
                          padding: const EdgeInsets.only(bottom: 16),
                          itemBuilder: (context, index) {
                            final session = _sessions[index];
                            return _userData?.isStudent == true
                                ? StudentSessionCard(
                                    session: session,
                                    canMarkAttendance: _controller
                                        .canMarkAttendance(
                                          session.startTime,
                                          session.endTime,
                                        ),
                                    onMarkAttendance: () =>
                                        _handleAttendanceMarking(session),
                                    onRevocationTap: () =>
                                        _showRevocationDialog(
                                          context,
                                          session.revocationReason,
                                        ),
                                  )
                                : TeacherSessionCard(
                                    session: session,
                                    isBroadcasting:
                                        _controller.isBroadcasting[session
                                            .id] ??
                                        false,
                                    canMarkAttendance: _controller
                                        .canMarkAttendance(
                                          session.startTime,
                                          session.endTime,
                                        ),
                                    onToggleBroadcast: () =>
                                        _toggleBroadcast(session.id),
                                  );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBroadcast(String sessionId) async {
    if (_controller.isBroadcasting[sessionId] == true) {
      await _controller.stopBroadcast(sessionId);
    } else {
      await _startBroadcast(sessionId);
    }
    setState(() {});
  }

  Future<void> _startBroadcast(String sessionId) async {
    _controller.isBroadcasting[sessionId] = true;
    setState(() {});

    _controller.broadcastStep(sessionId);

    _controller.broadcastTimers[sessionId]?.cancel();
    _controller.broadcastTimers[sessionId] = Timer.periodic(
      const Duration(seconds: 7),
      (timer) async {
        if (_controller.isBroadcasting[sessionId] != true) {
          timer.cancel();
          return;
        }
        await _controller.broadcastStep(sessionId);
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _handleAttendanceMarking(SessionData session) async {
    if (session.isTutorialOrPractical) {
      final biometricStatus = await _controller.checkBiometricStatus();

      if (biometricStatus['fingerprint'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FingerprintVerificationPage(
              sessionId: session.id,
              courseCode: session.courseCode ?? 'Unknown',
              courseName: session.sessionName,
              sessionType: session.sessionType,
            ),
          ),
        ).then((_) => _refreshData());
      } else if (biometricStatus['face'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FaceVerificationPageV2(
              sessionId: session.id,
              courseCode: session.courseCode ?? 'Unknown',
              courseName: session.sessionName,
              sessionType: session.sessionType,
            ),
          ),
        ).then((_) => _refreshData());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please set up biometric verification in Device Biometric settings',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UltrasonicPage(
            sessionId: session.id,
            sessionName: session.sessionName,
          ),
        ),
      ).then((_) => _refreshData());
    }
  }

  void _showRevocationDialog(BuildContext context, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Attendance Revoked',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your attendance for this session was revoked by the teacher.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reason:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                reason.isNotEmpty ? reason : 'No reason provided.',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
