import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceHistoryPage extends StatefulWidget {
  final String? selectedCourse;

  const AttendanceHistoryPage({
    super.key,
    this.selectedCourse,
  });

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  late Future<List<Map<String, dynamic>>> _attendanceRecords;
  String _filterCourse = 'All';

  @override
  void initState() {
    super.initState();
    // Set the filter to the selected course if provided
    if (widget.selectedCourse != null) {
      _filterCourse = widget.selectedCourse!;
    }
    _attendanceRecords = _fetchAttendanceHistory();
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return [];

      final userId = user!.email!.toLowerCase();
      final attendanceSnap = await FirebaseFirestore.instance
          .collection('Attendance')
          .where('email', isEqualTo: userId)
          .orderBy('markedAt', descending: true)
          .get();

      List<Map<String, dynamic>> records = [];

      for (var doc in attendanceSnap.docs) {
        final data = doc.data();
        final courseName = data['courseName'] ?? 'Unknown Course';
        final sessionId = data['sessionId'] ?? '';
        final markedAt = data['markedAt'] as Timestamp?;
        final status = data['status'] ?? 'absent';

        // Apply filter
        if (_filterCourse != 'All' && courseName != _filterCourse) {
          continue;
        }

        // Fetch session details for start and end times and session type
        Timestamp? startTime;
        Timestamp? endTime;
        String sessionType = '';
        try {
          final sessionSnap = await FirebaseFirestore.instance
              .collection('Sessions')
              .doc(sessionId)
              .get();
          
          if (sessionSnap.exists) {
            startTime = sessionSnap['start_time'] as Timestamp?;
            endTime = sessionSnap['end_time'] as Timestamp?;
            sessionType = sessionSnap['sessionsType'] ?? '';
          }
        } catch (e) {
          debugPrint('Error fetching session details: $e');
        }

        records.add({
          'id': doc.id,
          'sessionId': sessionId,
          'courseName': courseName,
          'markedAt': markedAt,
          'status': status,
          'verificationMethod': data['verificationMethod'] ?? 'unknown',
          'startTime': startTime,
          'endTime': endTime,
          'sessionType': sessionType,
        });
      }

      return records;
    } catch (e) {
      debugPrint('Error fetching attendance history: $e');
      return [];
    }
  }

  void _refreshAttendance() {
    setState(() {
      _attendanceRecords = _fetchAttendanceHistory();
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
            child: FutureBuilder<List<Map<String, dynamic>>>(
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
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                      final record = records[index];
                      final markedAt = record['markedAt'] as Timestamp?;
                      final startTime = record['startTime'] as Timestamp?;
                      final endTime = record['endTime'] as Timestamp?;
                      
                      final dateStr = markedAt != null
                          ? DateFormat('dd MMM yyyy').format(markedAt.toDate())
                          : 'N/A';
                      final startTimeStr = startTime != null
                          ? DateFormat('hh:mm a').format(startTime.toDate())
                          : 'N/A';
                      final endTimeStr = endTime != null
                          ? DateFormat('hh:mm a').format(endTime.toDate())
                          : 'N/A';
                      final sessionType = record['sessionType'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5E6D3),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date and Session Type on same line
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF636E72),
                                  ),
                                ),
                                const Spacer(),
                                if (sessionType.isNotEmpty)
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _getSessionTypeColor(sessionType),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _getSessionTypeInitial(sessionType),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Session time and Verification method on same line
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$startTimeStr - $endTimeStr',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF636E72),
                                    ),
                                  ),
                                ),
                                Icon(
                                  _getVerificationIcon(record['verificationMethod']),
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _getVerificationLabel(record['verificationMethod']),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF636E72),
                                    ),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
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

  String _getSessionTypeInitial(String sessionType) {
    if (sessionType.toLowerCase().contains('lecture')) {
      return 'L';
    } else if (sessionType.toLowerCase().contains('tutorial')) {
      return 'T';
    }
    return 'C';
  }

  Color _getSessionTypeColor(String sessionType) {
    if (sessionType.toLowerCase().contains('lecture')) {
      return const Color(0xFF8B4513); // Brown
    } else if (sessionType.toLowerCase().contains('tutorial')) {
      return const Color(0xFF8B4513); // Brown
    }
    return const Color(0xFF8B4513); // Brown
  }

  IconData _getVerificationIcon(String method) {
    switch (method) {
      case 'face':
        return Icons.face;
      case 'fingerprint':
        return Icons.fingerprint;
      case 'ultrasonic':
        return Icons.surround_sound;
      default:
        return Icons.check_circle;
    }
  }

  String _getVerificationLabel(String method) {
    switch (method) {
      case 'face':
        return 'Face Verification';
      case 'fingerprint':
        return 'Fingerprint';
      case 'ultrasonic':
        return 'Ultrasonic';
      default:
        return 'Verified';
    }
  }
}
