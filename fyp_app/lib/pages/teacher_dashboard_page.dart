import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  bool _loading = true;
  int _totalSessions = 0;
  List<Map<String, dynamic>> _sessionStats = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final teacherEmail = user.email!.toLowerCase();

      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(teacherEmail)
          .get();

      if (!userDoc.exists) {
        setState(() => _loading = false);
        return;
      }

      final sessionIds = List<String>.from(userDoc['sessionsId'] ?? []);
      int totalSessionsCount = sessionIds.length;
      List<Map<String, dynamic>> sessionStats = [];

      for (String sessionId in sessionIds) {
        final sessionDoc = await FirebaseFirestore.instance
            .collection('Sessions')
            .doc(sessionId)
            .get();

        if (!sessionDoc.exists) continue;

        final sessionData = sessionDoc.data()!;
        final sessionName = sessionData['sessionsName'] ?? 'Unknown';
        final courseCode = sessionData['courseCode'] ?? sessionId;

        final attendanceQuery = await FirebaseFirestore.instance
            .collection('Attendance')
            .where('sessionId', isEqualTo: sessionId)
            .get();

        int present = 0;

        final studentsQuery = await FirebaseFirestore.instance
            .collection('Users')
            .where('sessionsId', arrayContains: sessionId)
            .where('role', isEqualTo: 'student')
            .get();

        int totalStudents = studentsQuery.docs.length;

        present = attendanceQuery.docs
            .where((doc) => doc['status'] == 'present')
            .length;

        double percentage = 0;

        if (totalStudents > 0) {
          final uniqueDates = attendanceQuery.docs.map((d) {
            final ts = d['markedAt'] as Timestamp?;
            if (ts == null) return '';
            return DateFormat('yyyy-MM-dd').format(ts.toDate());
          }).toSet();

          int classesHeld = uniqueDates.isEmpty ? 1 : uniqueDates.length;
          int totalOpportunities = totalStudents * classesHeld;

          if (totalOpportunities > 0) {
            percentage = (present / totalOpportunities) * 100;
          }
        }

        sessionStats.add({
          'name': sessionName,
          'code': courseCode,
          'percentage': percentage.clamp(0.0, 100.0),
          'present': present,
          'totalStudents': totalStudents,
          'sessionId': sessionId,
        });
      }

      if (mounted) {
        setState(() {
          _totalSessions = totalSessionsCount;
          _sessionStats = sessionStats;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
      if (mounted) setState(() => _loading = false);
    }
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Display
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF546E7A),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat(
                            'EEEE, MMM dd, yyyy',
                          ).format(DateTime.now()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.white70,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Total Sessions Card
                  Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF81C3D7), Color(0xFF5BA3C0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.school,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Total Sessions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_totalSessions',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Session Overview List
                  const Text(
                    'My Sessions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sessionStats.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              children: const [
                                Icon(
                                  Icons.inbox_outlined,
                                  color: Colors.white54,
                                  size: 64,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No sessions available',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _sessionStats.length,
                          itemBuilder: (context, index) {
                            final stat = _sessionStats[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF546E7A),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _showManualAttendanceDialog(context, stat);
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF81C3D7),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.book,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stat['name'],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                stat['code'],
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${stat['percentage'].toStringAsFixed(0)}% Present',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    '${stat['present']}/${stat['totalStudents']} Students',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Colors.white54,
                                          size: 28,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Future<void> _showManualAttendanceDialog(
    BuildContext context,
    Map<String, dynamic> sessionStat,
  ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF3D4A4F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _ManualAttendanceSheet(
          sessionId: sessionStat['sessionId'],
          sessionName: sessionStat['name'],
        );
      },
    );
    _fetchDashboardData();
  }
}

class _ManualAttendanceSheet extends StatefulWidget {
  final String sessionId;
  final String sessionName;

  const _ManualAttendanceSheet({
    required this.sessionId,
    required this.sessionName,
  });

  @override
  State<_ManualAttendanceSheet> createState() => _ManualAttendanceSheetState();
}

class _ManualAttendanceSheetState extends State<_ManualAttendanceSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    try {
      // 1. Fetch students enrolled in this session
      final studentsQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('sessionsId', arrayContains: widget.sessionId)
          .where('role', isEqualTo: 'student')
          .get();

      // 2. Fetch today's attendance for this session
      // We fetch all attendance for this session and filter in memory to avoid
      // missing index issues (composite index on sessionId + markedAt).
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final attendanceQuery = await FirebaseFirestore.instance
          .collection('Attendance')
          .where('sessionId', isEqualTo: widget.sessionId)
          .get();

      // Map student Email -> Attendance Doc
      Map<String, DocumentSnapshot> attendanceMap = {};
      for (var doc in attendanceQuery.docs) {
        final data = doc.data();
        final markedAt = (data['markedAt'] as Timestamp?)?.toDate();

        // Filter for today
        if (markedAt != null &&
            markedAt.isAfter(startOfDay) &&
            markedAt.isBefore(endOfDay)) {
          final email = data['email'] as String?;
          if (email != null) {
            attendanceMap[email.toLowerCase()] = doc;
          }
        }
      }

      List<Map<String, dynamic>> students = [];

      for (var doc in studentsQuery.docs) {
        final data = doc.data();
        final email = (data['email'] as String?)?.toLowerCase() ?? '';

        String? status;
        String? attendanceDocId;
        String? revokedBy;

        if (attendanceMap.containsKey(email)) {
          final attendanceDoc = attendanceMap[email]!;
          final attendanceData = attendanceDoc.data() as Map<String, dynamic>?;
          status = attendanceData?['status'];
          attendanceDocId = attendanceDoc.id;
          revokedBy = attendanceData?['revokedBy'];
        }

        students.add({
          'id': doc.id, // email is docId usually, but let's use doc.id
          'name': data['fullName'] ?? 'Unknown',
          'idNumber': data['idNumber'] ?? '',
          'email': email,
          'status': status,
          'attendanceDocId': attendanceDocId,
          'revokedBy': revokedBy,
        });
      }

      if (mounted) {
        setState(() {
          _students = students;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching students: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markPresent(String studentEmail, String studentName) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Check if there's already an attendance record for today
      final existingAttendance = await FirebaseFirestore.instance
          .collection('Attendance')
          .where('sessionId', isEqualTo: widget.sessionId)
          .where('email', isEqualTo: studentEmail)
          .get();

      // Find today's record
      DocumentSnapshot? todayRecord;
      for (var doc in existingAttendance.docs) {
        final markedAt = (doc['markedAt'] as Timestamp?)?.toDate();
        if (markedAt != null &&
            markedAt.isAfter(startOfDay) &&
            markedAt.isBefore(endOfDay)) {
          todayRecord = doc;
          break;
        }
      }

      if (todayRecord != null) {
        // Update existing record (e.g., if it was revoked)
        await FirebaseFirestore.instance
            .collection('Attendance')
            .doc(todayRecord.id)
            .update({
              'status': 'present',
              'markedAt': Timestamp.fromDate(now),
              'verificationMethod': 'manual',
              'revokedBy': FieldValue.delete(),
              'revokedAt': FieldValue.delete(),
              'revocationReason': FieldValue.delete(),
            });
      } else {
        // Create new attendance record
        await FirebaseFirestore.instance.collection('Attendance').add({
          'sessionId': widget.sessionId,
          'courseName': widget.sessionName,
          'email': studentEmail,
          'status': 'present',
          'markedAt': Timestamp.fromDate(now),
          'verificationMethod': 'manual',
          'deviceToken': '', // N/A
          'distance': 0,
          'faceConfidence': 0,
          'latitude': 0,
          'longitude': 0,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked $studentName as Present')),
        );
        _fetchStudents(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error marking attendance: $e')));
      }
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
              child: const Text('Revoke'),
            ),
          ],
        );
      },
    );

    if (confirm == true && attendanceDocId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('Attendance')
            .doc(attendanceDocId)
            .update({
              'status': 'absent',
              'revocationReason': reasonController.text.trim(),
              'revokedAt': Timestamp.now(),
              'revokedBy': 'teacher',
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Revoked attendance for $studentName')),
          );
          _fetchStudents(); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error revoking attendance: $e')),
          );
        }
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
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _students.isEmpty
                ? const Center(
                    child: Text(
                      'No students found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final isPresent = student['status'] == 'present';
                      final isRevoked = student['revokedBy'] == 'teacher';

                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                student['name'],
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isRevoked)
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
                          student['idNumber'],
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: isPresent
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _revokeAttendance(
                                  student['name'],
                                  student['attendanceDocId'],
                                ),
                                child: const Text('Untake'),
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF81C3D7),
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: () => _markPresent(
                                  student['email'], // Use email for marking
                                  student['name'],
                                ),
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
