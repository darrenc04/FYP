import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_app/pages/fingerprint_verification_page.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'ultrasonic_page.dart';
import 'package:intl/intl.dart';

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

  // Audio player for teachers
  final AudioPlayer tonePlayer = AudioPlayer();
  Map<String, Timer> _broadcastTimers = {};
  Map<String, bool> _isBroadcasting = {};

  @override
  void initState() {
    super.initState();
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
          final sessionIds = List<String>.from(docSnap['sessionsId'] ?? []);

          List<Map<String, dynamic>> sessions = [];
          for (String sessionId in sessionIds) {
            try {
              final sessionSnap = await FirebaseFirestore.instance
                  .collection('Sessions')
                  .doc(sessionId)
                  .get();

              if (sessionSnap.exists) {
                final sessionData = sessionSnap.data() as Map<String, dynamic>;

                // Check if session is scheduled for today
                final startTime = sessionData['start_time'] as Timestamp?;
                if (startTime != null) {
                  final sessionDate = startTime.toDate();
                  final now = DateTime.now();

                  // Compare only date components (year, month, day)
                  final isToday =
                      sessionDate.year == now.year &&
                      sessionDate.month == now.month &&
                      sessionDate.day == now.day;

                  // Only add session if it's scheduled for today
                  if (isToday) {
                    // For students, check attendance - always check fresh from Firestore
                    if (role == 'student') {
                      final attendanceSnap = await FirebaseFirestore.instance
                          .collection('Sessions')
                          .doc(sessionId)
                          .collection('Attendance')
                          .doc(docId)
                          .get(
                            const GetOptions(source: Source.server),
                          ); // Force server read

                      // Check if attendance document exists AND has a valid 'status' field
                      final attendanceMarked =
                          attendanceSnap.exists &&
                          (attendanceSnap.data()?['status'] != null);

                      sessions.add({
                        'id': sessionId,
                        'attendanceMarked': attendanceMarked,
                        ...sessionData,
                      });
                    } else {
                      // For teachers, include session data
                      sessions.add({'id': sessionId, ...sessionData});
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
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
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
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      onPressed: _refreshData,
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
    final location = session['location'] ?? 'No Location';
    final lecturerName = session['lecturerName'] ?? 'Unknown';
    final attendanceMarked = session['attendanceMarked'] ?? false;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6D3),
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
                          style: const TextStyle(
                            color: Color(0xFF2D3436),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          endTimeStr,
                          style: const TextStyle(
                            color: Color(0xFF2D3436),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
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
                    color: const Color(0xFF8B4513),
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
                  child: Text(
                    '$sessionId $sessionName',
                    style: const TextStyle(
                      color: Color(0xFF2D3436),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.home_outlined,
                  color: Color(0xFF636E72),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(
                      color: Color(0xFF636E72),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
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
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: attendanceMarked
                        ? null
                        : () async {
                            final isTutorialOrPractical =
                                sessionType.toLowerCase().contains(
                                  'tutorial',
                                ) ||
                                sessionType.toLowerCase().contains('practical');

                            if (isTutorialOrPractical) {
                              // Use face verification for Tutorial/Practical
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      FingerprintVerificationPage(
                                        sessionId: session['id'],
                                        courseCode: session['courseCode'] ?? '',
                                        courseName: sessionName,
                                        sessionType: sessionType,
                                      ),
                                ),
                              );
                            } else {
                              // Use ultrasonic for Lecture Class
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MarkAttendancePage(
                                    sessionId: session['id'],
                                    sessionName: sessionName,
                                  ),
                                ),
                              );
                            }
                            if (mounted) {
                              await _refreshData();
                            }
                          },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: attendanceMarked
                            ? Colors.grey.withOpacity(0.1)
                            : const Color(0xFF4A9FE8).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: attendanceMarked
                              ? Colors.grey.withOpacity(0.3)
                              : const Color(0xFF4A9FE8),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            attendanceMarked
                                ? Icons.check_circle
                                : Icons.touch_app,
                            color: attendanceMarked
                                ? const Color(0xFF636E72)
                                : const Color(0xFF4A9FE8),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            attendanceMarked
                                ? 'Attendance Marked'
                                : 'Mark Attendance',
                            style: TextStyle(
                              color: attendanceMarked
                                  ? const Color(0xFF636E72)
                                  : const Color(0xFF4A9FE8),
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

  Widget _buildTeacherCard(Map<String, dynamic> session) {
    final sessionName = session['sessionsName'] ?? 'Unknown Session';
    final sessionType = session['sessionsType'] ?? 'Class';
    final location = session['location'] ?? 'No Location';
    final targetFrequency = session['targetFrequency'] as int?;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6D3),
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
                          style: const TextStyle(
                            color: Color(0xFF2D3436),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          endTimeStr,
                          style: const TextStyle(
                            color: Color(0xFF2D3436),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
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
                    color: const Color(0xFF8B4513),
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
                  child: Text(
                    '$sessionId $sessionName',
                    style: const TextStyle(
                      color: Color(0xFF2D3436),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.home_outlined,
                  color: Color(0xFF636E72),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(
                      color: Color(0xFF636E72),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Broadcast Button
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _toggleBroadcast(sessionId),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isBroadcasting
                            ? Colors.red.withOpacity(0.1)
                            : const Color(0xFF4A9FE8).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isBroadcasting
                              ? Colors.red
                              : const Color(0xFF4A9FE8),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isBroadcasting ? Icons.stop : Icons.play_arrow,
                            color: isBroadcasting
                                ? Colors.red
                                : const Color(0xFF4A9FE8),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isBroadcasting
                                ? 'Stop Broadcast'
                                : 'Start Broadcast',
                            style: TextStyle(
                              color: isBroadcasting
                                  ? Colors.red
                                  : const Color(0xFF4A9FE8),
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
}
