import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../model/home_user_data.dart';
import '../model/session_data.dart';
import '../services/attendance_service.dart';

// Default public holidays list (as fallback if API is unavailable)
final Set<String> defaultPublicHolidays = {
  '2025-01-25', '2025-02-01', '2025-02-10', '2025-02-11', '2025-03-28',
  '2025-04-10', '2025-04-11', '2025-05-01', '2025-05-22', '2025-06-03',
  '2025-07-07', '2025-07-30', '2025-08-31', '2025-09-16', '2025-10-24',
  '2025-12-25', '2026-01-01', '2026-01-29', '2026-02-10', '2026-02-11',
  '2026-02-14', '2026-04-10', '2026-05-01', '2026-05-24', '2026-06-03',
  '2026-07-07', '2026-08-31', '2026-09-16', '2026-10-29', '2026-12-25',
  '2025-11-25', // testing
};

class HomeController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AttendanceService _attendanceService = AttendanceService();
  final AudioPlayer tonePlayer = AudioPlayer();

  Set<String> publicHolidays = defaultPublicHolidays;
  Map<String, Timer> broadcastTimers = {};
  Map<String, bool> isBroadcasting = {};

  /// Check if a date is a public holiday
  bool isPublicHoliday(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    return publicHolidays.contains(dateString);
  }

  /// Fetch public holidays from Calendarific API for Malaysia
  Future<Set<String>> loadPublicHolidays() async {
    try {
      final now = DateTime.now();
      final year = now.year;

      final response = await _fetchHolidaysFromApi(year);

      if (response.isNotEmpty) {
        return response.toSet();
      } else {
        return defaultPublicHolidays;
      }
    } catch (e) {
      debugPrint('Error loading public holidays: $e');
      return defaultPublicHolidays;
    }
  }

  /// Fetch holidays from Calendarific API for Malaysia
  Future<List<String>> _fetchHolidaysFromApi(int year) async {
    try {
      const String apiKey = 'USE WHEN NEEDED';

      final url = Uri.parse(
        'https://calendarific.com/api/v2/holidays?api_key=$apiKey&country=MY&year=$year',
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

        debugPrint(
          'Loaded ${holidayDates.length} holidays from Calendarific API',
        );
        return holidayDates;
      } else {
        debugPrint(
          'Failed to fetch holidays from Calendarific: ${response.statusCode}',
        );
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching from Calendarific API: $e');
      return [];
    }
  }

  /// Fetch user data from Firestore
  Future<HomeUserData?> fetchUserData() async {
    try {
      final user = _auth.currentUser;
      if (user?.email == null) return null;

      final docId = user!.email!.toLowerCase();
      final docSnap = await _firestore.collection('Users').doc(docId).get();

      if (docSnap.exists) {
        final fullName = docSnap['fullName'] ?? 'User';
        final role = docSnap['role'] ?? 'student';
        final profilePicture = docSnap['profilePicture'] as String?;

        return HomeUserData(
          name: fullName,
          role: role,
          profilePicture: profilePicture,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return null;
    }
  }

  /// Fetch sessions for the current user
  Future<List<SessionData>> fetchSessions(String userRole) async {
    try {
      final user = _auth.currentUser;
      if (user?.email == null) return [];

      final docId = user!.email!.toLowerCase();
      final docSnap = await _firestore.collection('Users').doc(docId).get();

      if (!docSnap.exists) return [];

      final sessionIds = List<String>.from(docSnap['sessionsId'] ?? []);

      // Trigger auto-absent marking for students
      if (userRole.toLowerCase() == 'student') {
        _attendanceService.markPastAbsences(docId);
      }

      List<SessionData> sessions = [];
      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      for (String sessionId in sessionIds) {
        try {
          final isCancelled = isPublicHoliday(today);

          final sessionSubDoc = await _firestore
              .collection('Sessions')
              .doc(sessionId)
              .collection(todayStr)
              .doc('session_info')
              .get();

          if (sessionSubDoc.exists) {
            final sessionData = sessionSubDoc.data() as Map<String, dynamic>;

            if (userRole.toLowerCase() == 'student') {
              final attendanceSnap = await _firestore
                  .collection('Attendance')
                  .where('email', isEqualTo: docId)
                  .where('sessionId', isEqualTo: sessionId)
                  .get(const GetOptions(source: Source.server));

              bool attendanceMarked = false;
              bool attendanceRevoked = false;
              String revocationReason = '';

              if (attendanceSnap.docs.isNotEmpty) {
                for (var doc in attendanceSnap.docs) {
                  final data = doc.data();

                  bool isMatch = false;
                  if (data.containsKey('sessionDate')) {
                    if (data['sessionDate'] == todayStr) {
                      isMatch = true;
                    }
                  } else {
                    final markedAt = (data['markedAt'] as Timestamp?)?.toDate();
                    if (markedAt != null) {
                      if (markedAt.year == today.year &&
                          markedAt.month == today.month &&
                          markedAt.day == today.day) {
                        isMatch = true;
                      }
                    }
                  }

                  if (isMatch) {
                    if (data['status'] == 'present') {
                      attendanceMarked = true;
                    } else if (data['status'] == 'absent' &&
                        data['revokedBy'] == 'teacher') {
                      attendanceRevoked = true;
                      revocationReason =
                          data['revocationReason'] ?? 'No reason provided';
                    }
                    break;
                  }
                }
              }

              sessions.add(
                SessionData.fromMap({
                  ...sessionData,
                  'attendanceMarked': attendanceMarked,
                  'attendanceRevoked': attendanceRevoked,
                  'revocationReason': revocationReason,
                  'isCancelled': isCancelled,
                }, sessionId),
              );
            } else {
              sessions.add(
                SessionData.fromMap({
                  ...sessionData,
                  'isCancelled': isCancelled,
                }, sessionId),
              );
            }
          }
        } catch (e) {
          debugPrint('Error fetching session $sessionId for $todayStr: $e');
        }
      }

      return sessions;
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
      return [];
    }
  }

  /// Check if current time is within session attendance window
  bool canMarkAttendance(Timestamp? startTime, Timestamp? endTime) {
    if (startTime == null || endTime == null) return false;

    final now = DateTime.now();
    final start = startTime.toDate();
    final end = endTime.toDate();

    if (now.weekday != start.weekday) {
      return false;
    }

    final nowTimeOfDay = now.hour * 60 + now.minute;
    final startTimeOfDay = start.hour * 60 + start.minute;
    final endTimeOfDay = end.hour * 60 + end.minute;

    return nowTimeOfDay >= startTimeOfDay && nowTimeOfDay <= endTimeOfDay;
  }

  /// Check biometric verification status for student
  Future<Map<String, bool>> checkBiometricStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {'face': false, 'fingerprint': false};

      final docId = user.email!.toLowerCase();
      final userDoc = await _firestore.collection('Users').doc(docId).get();

      final isFaceVerified = userDoc.data()?['faceVerified'] ?? false;
      final isFingerprintVerified =
          userDoc.data()?['fingerprintVerified'] ?? false;

      return {'face': isFaceVerified, 'fingerprint': isFingerprintVerified};
    } catch (e) {
      debugPrint('Error checking biometric status: $e');
      return {'face': false, 'fingerprint': false};
    }
  }

  /// Generate audio tone for teacher broadcast
  Future<String> generateToneAudio(int frequency) async {
    const int sampleRate = 44100;
    const int durationSeconds = 60;
    final int numSamples = sampleRate * durationSeconds;

    List<int> samples = [];
    for (int i = 0; i < numSamples; i++) {
      double time = i / sampleRate;
      double sample = math.sin(2 * math.pi * frequency * time);

      double volumeScale;
      if (frequency >= 17000) {
        volumeScale = 1.0;
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

    final wavBytes = [...header, ...samples];

    if (kIsWeb) {
      // For Web: Return a Data URI instead of saving to file
      final base64Audio = base64Encode(wavBytes);
      return 'data:audio/wav;base64,$base64Audio';
    } else {
      // For Mobile: Save to file as before
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String filePath = p.join(appDocDir.path, "tone_${frequency}hz.wav");
      final file = File(filePath);

      if (await file.exists()) {
        return filePath;
      }

      await file.writeAsBytes(wavBytes);
      return filePath;
    }
  }

  List<int> _intToBytes(int value, int numBytes) {
    List<int> bytes = [];
    for (int i = 0; i < numBytes; i++) {
      bytes.add((value >> (8 * i)) & 0xFF);
    }
    return bytes;
  }

  /// Broadcast step for teacher
  Future<void> broadcastStep(String sessionId) async {
    try {
      final random = math.Random();
      final step = random.nextInt(21);
      final targetFrequency = 18000 + (step * 100);

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await _firestore
          .collection('Sessions')
          .doc(sessionId)
          .collection(todayStr)
          .doc('session_info')
          .update({
            'targetFrequency': targetFrequency,
            'frequencyGeneratedAt': FieldValue.serverTimestamp(),
          });

      final toneSource = await generateToneAudio(targetFrequency);
      await tonePlayer.stop();

      if (kIsWeb) {
        // Play from Data URI
        // Ensure just_audio supports Uri parsing for data:
        await tonePlayer.setAudioSource(AudioSource.uri(Uri.parse(toneSource)));
      } else {
        // Play from File Path
        await tonePlayer.setFilePath(toneSource);
      }

      await tonePlayer.setLoopMode(LoopMode.one);
      await tonePlayer.play();
    } catch (e) {
      debugPrint('Error in broadcast step: $e');
    }
  }

  /// Stop broadcast
  Future<void> stopBroadcast(String sessionId) async {
    broadcastTimers[sessionId]?.cancel();
    broadcastTimers.remove(sessionId);
    await tonePlayer.stop();
    isBroadcasting[sessionId] = false;
  }

  /// Dispose resources
  void dispose() {
    tonePlayer.dispose();
    for (var timer in broadcastTimers.values) {
      timer.cancel();
    }
  }
}
