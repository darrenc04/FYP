import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:fyp_app/pages/profile_page.dart';
import 'attendance_overview_page.dart';
import 'teacher_dashboard_page.dart';
import 'ultrasonic_page.dart';
import 'face_verification_page_v2.dart';
import 'fingerprint_verification_page.dart';

// Default public holidays list (as fallback if Firestore is unavailable)
final Set<String> defaultPublicHolidays = {
  '2025-01-25', // Thaipusam
  '2025-02-01', // Federal Territory Day
  '2025-02-10', // Chinese New Year
  '2025-02-11', // Chinese New Year (replacement)
  '2025-03-28', // Nuzul Al-Quran
  '2025-04-10', // Hari Raya Aidilfitri
  '2025-04-11', // Hari Raya Aidilfitri (replacement)
  '2025-05-01', // Labour Day
  '2025-05-22', // Wesak Day
  '2025-06-03', // Agong\'s Birthday
  '2025-07-07', // Awal Muharram
  '2025-07-30', // Nuzul Al-Quran
  '2025-08-31', // National Day
  '2025-09-16', // Malaysia Day
  '2025-10-24', // Deepavali
  '2025-12-25', // Christmas Day
  '2026-01-01', // New Year
  '2026-01-29', // Thaipusam
  '2026-02-10', // Chinese New Year
  '2026-02-11', // Chinese New Year (replacement)
  '2026-02-14', // Federal Territory Day
  '2026-04-10', // Nuzul Al-Quran
  '2026-05-01', // Labour Day
  '2026-05-24', // Hari Raya Aidilfitri
  '2026-06-03', // Agong\'s Birthday
  '2026-07-07', // Awal Muharram
  '2026-08-31', // National Day
  '2026-09-16', // Malaysia Day
  '2026-10-29', // Deepavali
  '2026-12-25', // Christmas Day
  '2025-11-25'  // testing
};

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  String _userName = 'User';
  String _userRole = 'student';
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _profilePicture; // Add profile picture
  Set<String> _publicHolidays = defaultPublicHolidays; // Dynamically loaded from Firestore

  // Audio player for teachers
  final AudioPlayer tonePlayer = AudioPlayer();
  Map<String, Timer> _broadcastTimers = {};
  Map<String, bool> _isBroadcasting = {};

  @override
  void initState() {
    super.initState();
    _loadPublicHolidays();
    _fetchUserData();
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
    // Refresh when returning to this page
    _refreshData();
  }

  @override
  void dispose() {
    tonePlayer.dispose();
    for (var timer in _broadcastTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  /// Check if a date is a public holiday
  bool _isPublicHoliday(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    return _publicHolidays.contains(dateString);
  }

  /// Fetch public holidays from Calendarific API for Malaysia
  Future<void> _loadPublicHolidays() async {
    try {
      final now = DateTime.now();
      final year = now.year;
      
      // Fetch holidays from Calendarific API for Malaysia
      final response = await _fetchHolidaysFromApi(year);
      
      if (response.isNotEmpty && mounted) {
        setState(() {
          _publicHolidays = response.toSet();
        });
      } else if (mounted) {
        // Fallback to default if API returns empty
        setState(() {
          _publicHolidays = defaultPublicHolidays;
        });
      }
    } catch (e) {
      debugPrint('Error loading public holidays: $e');
      // Use default on error
      if (mounted) {
        setState(() {
          _publicHolidays = defaultPublicHolidays;
        });
      }
    }
  }

  /// Fetch holidays from Calendarific API for Malaysia
  Future<List<String>> _fetchHolidaysFromApi(int year) async {
    try {

      // const String apiKey = 'SWt92k3yzLVrXcUFdXanvvqbvqokcqao';
      const String apiKey = 'USE WHEN NEEDED';
      
      final url = Uri.parse(
        'https://calendarific.com/api/v2/holidays?api_key=$apiKey&country=MY&year=$year'
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          debugPrint('No holidays data returned from Calendarific API');
          return [];
        }
        
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> holidays = data['response']?['holidays'] ?? [];
        
        final List<String> holidayDates = [];
        for (var holiday in holidays) {
          final date = holiday['date']?['iso'] as String?;
          if (date != null && date.isNotEmpty) {
            holidayDates.add(date);
          }
        }
        
        debugPrint('Loaded ${holidayDates.length} holidays from Calendarific API');
        return holidayDates;
      } else {
        debugPrint('Failed to fetch holidays from Calendarific: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching from Calendarific API: $e');
      return [];
    }
  }

  /// Generate weekly sessions for today and upcoming days
  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email != null) {
        final docId = user!.email!.toLowerCase();
        final docSnap = await FirebaseFirestore.instance
            .collection('Users')
            .doc(docId)
            .get();

        if (docSnap.exists && mounted) {
          final fullName = docSnap['fullName'] ?? 'User';
          final role = docSnap['role'] ?? 'student';
          final profilePicture = docSnap['profilePicture'] as String?;
          final sessionIds = List<String>.from(docSnap['sessionsId'] ?? []);

          List<Map<String, dynamic>> sessions = [];
          final now = DateTime.now();

          for (String sessionId in sessionIds) {
            try {
              final sessionSnap = await FirebaseFirestore.instance
                  .collection('Sessions')
                  .doc(sessionId)
                  .get();

              if (sessionSnap.exists) {
                final sessionData = sessionSnap.data() as Map<String, dynamic>;
                final startTime = sessionData['start_time'] as Timestamp?;

                if (startTime != null) {
                  final sessionDate = startTime.toDate();

                  // Check if session is scheduled for the same day of week (recurring weekly)
                  final sessionDayOfWeek =
                      sessionDate.weekday; // 1=Monday, 7=Sunday
                  final todayDayOfWeek = now.weekday;

                  // Only add sessions scheduled for the same day of week
                  if (sessionDayOfWeek == todayDayOfWeek) {
                    // Check if today is a public holiday
                    final isCancelled = _isPublicHoliday(now);

                    // For students, check attendance
                    if (role == 'student') {
                      // Check if attendance was marked in Attendance collection
                      final attendanceSnap = await FirebaseFirestore.instance
                          .collection('Attendance')
                          .where('email', isEqualTo: docId)
                          .where('sessionId', isEqualTo: sessionId)
                          .limit(1)
                          .get(const GetOptions(source: Source.server));

                      bool attendanceMarked = false;
                      bool attendanceRevoked = false;
                      String revocationReason = '';

                      if (attendanceSnap.docs.isNotEmpty) {
                        final data = attendanceSnap.docs.first.data();
                        if (data['status'] == 'present') {
                          attendanceMarked = true;
                        } else if (data['status'] == 'absent' &&
                            data['revokedBy'] == 'teacher') {
                          attendanceRevoked = true;
                          revocationReason =
                              data['revocationReason'] ?? 'No reason provided';
                        }
                      }

                      sessions.add({
                        ...sessionData,
                        'id': sessionId,
                        'attendanceMarked': attendanceMarked,
                        'attendanceRevoked': attendanceRevoked,
                        'revocationReason': revocationReason,
                        'isCancelled': isCancelled,
                      });
                    } else {
                      // For teachers
                      sessions.add({
                        ...sessionData,
                        'id': sessionId,
                        'isCancelled': isCancelled,
                      });
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('Error fetching session $sessionId: $e');
            }
          }

          if (mounted) {
            setState(() {
              _userName = fullName;
              _userRole = role.toLowerCase();
              _profilePicture = profilePicture;
              _sessions = sessions;
              _loading = false;
            });
          }
        } else if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _loading = true;
      _sessions = []; // Clear cached sessions
    });
    await _loadPublicHolidays();
    await _fetchUserData();
  }

  String _getSessionTypeInitial(String sessionType) {
    if (sessionType.toLowerCase().contains('lecture')) {
      return 'L';
    } else if (sessionType.toLowerCase().contains('tutorial')) {
      return 'T';
    }
    return 'C';
  }

  // Check if current time is within session attendance window
  bool _canMarkAttendance(Timestamp? startTime, Timestamp? endTime) {
    if (startTime == null || endTime == null) return false;

    final now = DateTime.now();
    final start = startTime.toDate();
    final end = endTime.toDate();

    // Check if today is the same day of week as the session
    if (now.weekday != start.weekday) {
      return false;
    }

    // Check if current time is within the session time window (ignoring the date)
    final nowTimeOfDay = now.hour * 60 + now.minute; // minutes since midnight
    final startTimeOfDay = start.hour * 60 + start.minute;
    final endTimeOfDay = end.hour * 60 + end.minute;

    return nowTimeOfDay >= startTimeOfDay && nowTimeOfDay <= endTimeOfDay;
  }

  // Generate audio tone for teacher
  Future<String> _generateToneAudio(int frequency) async {
    const int sampleRate = 44100;
    const int durationSeconds = 60;
    final int numSamples = sampleRate * durationSeconds;

    List<int> samples = [];
    for (int i = 0; i < numSamples; i++) {
      double time = i / sampleRate;
      double sample = math.sin(2 * math.pi * frequency * time);

      double volumeScale;
      if (frequency >= 17000) {
        volumeScale = 1.0; // Max volume for near-ultrasound to ensure detection
      } else if (frequency >= 15000) {
        volumeScale = 0.5;
      } else if (frequency >= 13000) {
        volumeScale = 0.15;
      } else if (frequency >= 11000) {
        volumeScale = 0.12;
      } else if (frequency >= 9000) {
        volumeScale = 0.10;
      } else {
        volumeScale = 0.05;
      }

      int pcmSample = (sample * volumeScale * 32767).round();
      samples.add(pcmSample & 0xFF);
      samples.add((pcmSample >> 8) & 0xFF);
    }

    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String filePath = p.join(appDocDir.path, "tone_${frequency}hz.wav");
    final file = File(filePath);

    if (await file.exists()) {
      return filePath;
    }

    final dataSize = samples.length;
    final header = [
      0x52,
      0x49,
      0x46,
      0x46,
      ..._intToBytes(36 + dataSize, 4),
      0x57,
      0x41,
      0x56,
      0x45,
      0x66,
      0x6D,
      0x74,
      0x20,
      0x10,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x01,
      0x00,
      ..._intToBytes(sampleRate, 4),
      ..._intToBytes(sampleRate * 2, 4),
      0x02,
      0x00,
      0x10,
      0x00,
      0x64,
      0x61,
      0x74,
      0x61,
      ..._intToBytes(dataSize, 4),
    ];

    await file.writeAsBytes([...header, ...samples]);
    return filePath;
  }

  List<int> _intToBytes(int value, int numBytes) {
    List<int> bytes = [];
    for (int i = 0; i < numBytes; i++) {
      bytes.add((value >> (8 * i)) & 0xFF);
    }
    return bytes;
  }

  Future<void> _toggleBroadcast(String sessionId) async {
    if (_isBroadcasting[sessionId] == true) {
      await _stopBroadcast(sessionId);
    } else {
      await _startBroadcast(sessionId);
    }
  }

  Future<void> _startBroadcast(String sessionId) async {
    setState(() {
      _isBroadcasting[sessionId] = true;
    });

    // Immediate first run (don't await, so timer starts immediately)
    _broadcastStep(sessionId);

    // Schedule periodic updates every 7 seconds
    _broadcastTimers[sessionId]?.cancel(); // Safety check
    _broadcastTimers[sessionId] = Timer.periodic(const Duration(seconds: 7), (
      timer,
    ) async {
      if (_isBroadcasting[sessionId] != true) {
        timer.cancel();
        return;
      }
      await _broadcastStep(sessionId);
    });
  }

  Future<void> _broadcastStep(String sessionId) async {
    try {
      // Generate random frequency between 18000-20000 Hz
      // Generate random frequency between 18000-20000 Hz in 100 Hz steps
      // Range: 18000, 18100, 18200, ..., 20000 (21 possibilities)
      final random = math.Random();
      final step = random.nextInt(21);
      final targetFrequency = 18000 + (step * 100);

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('Sessions')
          .doc(sessionId)
          .update({
            'targetFrequency': targetFrequency,
            'frequencyGeneratedAt': FieldValue.serverTimestamp(),
          });

      // Play Audio
      final tonePath = await _generateToneAudio(targetFrequency);
      await tonePlayer.stop(); // Stop previous tone
      await tonePlayer.setFilePath(tonePath);
      await tonePlayer.setLoopMode(LoopMode.one); // Loop while active
      await tonePlayer.play();

      if (mounted) {
        setState(() {
          // Trigger rebuild to show current frequency if needed
        });
      }
    } catch (e) {
      debugPrint('Error in broadcast step: $e');
      _stopBroadcast(sessionId); // Stop on error
    }
  }

  Future<void> _stopBroadcast(String sessionId) async {
    _broadcastTimers[sessionId]?.cancel();
    _broadcastTimers.remove(sessionId);
    await tonePlayer.stop();

    if (mounted) {
      setState(() {
        _isBroadcasting[sessionId] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF3D4A4F);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: user info + actions
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilePage(),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage:
                          _profilePicture != null && _profilePicture!.isNotEmpty
                          ? NetworkImage(_profilePicture!)
                          : null,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: _profilePicture == null || _profilePicture!.isEmpty
                          ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _userRole == 'teacher' ? 'Teacher' : 'Student',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFF3D4A4F),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/settings');
                      },
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Color(0xFF3D4A4F),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Title row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Today's classes",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (_userRole == 'teacher')
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF81C3D7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const TeacherDashboardPage(),
                            ),
                          );
                        },
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        icon: const Icon(
                          Icons.dashboard_outlined,
                          color: Color(0xFF3D4A4F),
                        ),
                      ),
                    ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AttendanceOverviewPage(),
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      icon: const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF3D4A4F),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Session cards list
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
                            return _userRole == 'student'
                                ? _buildStudentCard(session)
                                : _buildTeacherCard(session);
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

  Widget _buildStudentCard(Map<String, dynamic> session) {
    final sessionId = session['id'] ?? 'Unknown ID';
    final sessionName = session['sessionsName'] ?? 'Unknown Session';
    final sessionType = session['sessionsType'] ?? 'Class';

    final lecturerName = session['lecturerName'] ?? 'Unknown';
    final attendanceMarked = session['attendanceMarked'] ?? false;
    final attendanceRevoked = session['attendanceRevoked'] ?? false;
    final revocationReason = session['revocationReason'] ?? '';
    final isCancelled = session['isCancelled'] ?? false;
    final sessionTypeInitial = _getSessionTypeInitial(sessionType);

    // Extract and format time
    final startTime = session['start_time'] as Timestamp?;
    final endTime = session['end_time'] as Timestamp?;
    String startTimeStr = '';
    String endTimeStr = '';

    if (startTime != null) {
      final startDateTime = startTime.toDate();
      startTimeStr = DateFormat('hh:mm a').format(startDateTime).toUpperCase();
    }

    if (endTime != null) {
      final endDateTime = endTime.toDate();
      endTimeStr = DateFormat('hh:mm a').format(endDateTime).toUpperCase();
    }

    final isSessionActive =
        _canMarkAttendance(startTime, endTime) && !isCancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isCancelled ? Colors.red.shade100 : const Color(0xFFF5E6D3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time display on the left
                if (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty)
                  Container(
                    width: 70,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          startTimeStr,
                          style: TextStyle(
                            color: isCancelled
                                ? Colors.red
                                : const Color(0xFF2D3436),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        Text(
                          endTimeStr,
                          style: TextStyle(
                            color: isCancelled
                                ? Colors.red
                                : const Color(0xFF2D3436),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty)
                  const SizedBox(width: 12),
                // Session type icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCancelled ? Colors.red : const Color(0xFF8B4513),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      sessionTypeInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$sessionId $sessionName',
                        style: TextStyle(
                          color: isCancelled
                              ? Colors.red
                              : const Color(0xFF2D3436),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          decoration: isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isCancelled)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Public Holiday - Class Cancelled',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: Color(0xFF636E72),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lecturerName,
                    style: const TextStyle(
                      color: Color(0xFF636E72),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Action Button
                if (isCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red,
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_busy,
                          color: Colors.red,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Cancelled',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (attendanceRevoked)
                  ElevatedButton(
                    onPressed: () =>
                        _showRevocationDialog(context, revocationReason),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Absent',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (attendanceMarked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B894).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00B894),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF00B894),
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Marked',
                          style: TextStyle(
                            color: Color(0xFF00B894),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: isSessionActive
                        ? () => _handleAttendanceMarking(session)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSessionActive
                          ? const Color(0xFF4A9FE8)
                          : Colors.grey.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Mark Attendance',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> session) {
    final sessionName = session['sessionsName'] ?? 'Unknown Session';
    final sessionType = session['sessionsType'] ?? 'Class';
    final isCancelled = session['isCancelled'] ?? false;

    final sessionId = session['id'];
    final sessionTypeInitial = _getSessionTypeInitial(sessionType);
    final isBroadcasting = _isBroadcasting[sessionId] ?? false;

    // Extract and format time
    final startTime = session['start_time'] as Timestamp?;
    final endTime = session['end_time'] as Timestamp?;
    String startTimeStr = '';
    String endTimeStr = '';

    if (startTime != null) {
      final startDateTime = startTime.toDate();
      startTimeStr = DateFormat('hh:mm a').format(startDateTime).toUpperCase();
    }

    if (endTime != null) {
      final endDateTime = endTime.toDate();
      endTimeStr = DateFormat('hh:mm a').format(endDateTime).toUpperCase();
    }

    final isSessionActive =
        _canMarkAttendance(startTime, endTime) && !isCancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isCancelled ? Colors.red.shade100 : const Color(0xFFF5E6D3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time display on the left
                if (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty)
                  Container(
                    width: 70,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          startTimeStr,
                          style: TextStyle(
                            color: isCancelled
                                ? Colors.red
                                : const Color(0xFF2D3436),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        Text(
                          endTimeStr,
                          style: TextStyle(
                            color: isCancelled
                                ? Colors.red
                                : const Color(0xFF2D3436),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty)
                  const SizedBox(width: 12),
                // Session type icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCancelled ? Colors.red : const Color(0xFF8B4513),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      sessionTypeInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$sessionId $sessionName',
                        style: TextStyle(
                          color: isCancelled
                              ? Colors.red
                              : const Color(0xFF2D3436),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          decoration: isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isCancelled)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Public Holiday - Class Cancelled',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Broadcast Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isSessionActive
                        ? () => _toggleBroadcast(sessionId)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSessionActive
                            ? (isBroadcasting
                                  ? Colors.red.withOpacity(0.1)
                                  : const Color(0xFF4A9FE8).withOpacity(0.1))
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSessionActive
                              ? (isBroadcasting
                                    ? Colors.red
                                    : const Color(0xFF4A9FE8))
                              : Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isBroadcasting ? Icons.stop : Icons.play_arrow,
                            color: isSessionActive
                                ? (isBroadcasting
                                      ? Colors.red
                                      : const Color(0xFF4A9FE8))
                                : const Color(0xFF636E72),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCancelled
                                ? 'Cancelled'
                                : isBroadcasting
                                ? 'Stop Broadcast'
                                : 'Start Broadcast',
                            style: TextStyle(
                              color: isSessionActive
                                  ? (isBroadcasting
                                        ? Colors.red
                                        : const Color(0xFF4A9FE8))
                                  : const Color(0xFF636E72),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAttendanceMarking(Map<String, dynamic> session) async {
    final sessionType = session['sessionsType'] ?? 'Lecture Class';
    final sessionId = session['id'];
    final sessionName = session['sessionsName'] ?? 'Unknown Session';
    final courseCode = session['courseCode'] ?? 'Unknown';
    final courseName = session['courseName'] ?? 'Unknown Course';

    // Route to different verification pages based on session type
    if (sessionType.toLowerCase().contains('tutorial') ||
        sessionType.toLowerCase().contains('practical')) {
      // For Tutorial and Practical: check which biometric methods are verified
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        final docId = user.email!.toLowerCase();
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(docId)
            .get();

        final isFaceVerified = userDoc.data()?['faceVerified'] ?? false;
        final isFingerprintVerified =
            userDoc.data()?['fingerprintVerified'] ?? false;

        // Routing logic:
        // - If both face and fingerprint verified: use FaceVerificationPageV2
        // - If only face verified: use FaceVerificationPageV2
        // - If only fingerprint verified: use FingerprintVerificationPage
        if (isFaceVerified) {
          // Use face verification if available
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FaceVerificationPageV2(
                sessionId: sessionId,
                courseCode: courseCode,
                courseName: courseName,
                sessionType: sessionType,
              ),
            ),
          ).then((_) => _refreshData());
        } else if (isFingerprintVerified) {
          // Use fingerprint verification if only fingerprint is verified
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FingerprintVerificationPage(
                sessionId: sessionId,
                courseCode: courseCode,
                courseName: courseName,
                sessionType: sessionType,
              ),
            ),
          ).then((_) => _refreshData());
        } else {
          // No biometric verified - show error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Please set up biometric verification in Device Biometric settings'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error checking biometric status: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading biometric settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Use ultrasonic verification for Lecture classes
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MarkAttendancePage(
            sessionId: sessionId,
            sessionName: sessionName,
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
