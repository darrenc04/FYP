import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({super.key});

  @override
  State<AttendanceHistoryPage> createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  late Future<List<Map<String, dynamic>>> _attendanceRecords;
  String _filterCourse = 'All';
  List<String> _courses = ['All'];

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _attendanceRecords = _fetchAttendanceHistory();
  }

  Future<void> _loadCourses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email != null) {
        final docId = user!.email!.toLowerCase();
        final docSnap = await FirebaseFirestore.instance
            .collection('Users')
            .doc(docId)
            .get();

        if (docSnap.exists) {
          final sessionIds = List<String>.from(docSnap['sessionsId'] ?? []);
          final courses = <String>{'All'};

          for (String sessionId in sessionIds) {
            try {
              final sessionSnap = await FirebaseFirestore.instance
                  .collection('Sessions')
                  .doc(sessionId)
                  .get();

              if (sessionSnap.exists) {
                final sessionName = sessionSnap['sessionsName'] ?? 'Unknown';
                courses.add(sessionName);
              }
            } catch (e) {
              debugPrint('Error loading course $sessionId: $e');
            }
          }

          if (mounted) {
            setState(() {
              _courses = courses.toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
    }
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

        records.add({
          'id': doc.id,
          'sessionId': sessionId,
          'courseName': courseName,
          'markedAt': markedAt,
          'status': status,
          'verificationMethod': data['verificationMethod'] ?? 'unknown',
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
          // Filter button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                  ),
                  child: DropdownButton<String>(
                    value: _filterCourse,
                    underline: const SizedBox.shrink(),
                    items: _courses
                        .map((course) => DropdownMenuItem(
                              value: course,
                              child: Text(
                                course,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2D3436),
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _filterCourse = value;
                          _attendanceRecords = _fetchAttendanceHistory();
                        });
                      }
                    },
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _refreshAttendance,
                )
              ],
            ),
          ),
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
                      final timeStr = markedAt != null
                          ? DateFormat('hh:mm a').format(markedAt.toDate())
                          : 'N/A';

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
                            // Course name and code
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        record['sessionId']+ ' ' + record['courseName'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2D3436),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: record['status'] == 'present'
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    record['status'].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: record['status'] == 'present'
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Time marked and verification method
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Time Marked: $timeStr',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF636E72),
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  _getVerificationIcon(record['verificationMethod']),
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getVerificationLabel(record['verificationMethod']),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF636E72),
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
