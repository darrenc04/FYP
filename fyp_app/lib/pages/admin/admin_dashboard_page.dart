import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_user_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _totalTeachers = 0;
  int _totalStudents = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final teachersQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('role', isEqualTo: 'teacher')
          .count()
          .get();

      final studentsQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('role', isEqualTo: 'student')
          .count()
          .get();

      if (mounted) {
        setState(() {
          _totalTeachers = teachersQuery.count ?? 0;
          _totalStudents = studentsQuery.count ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3D4A4F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3D4A4F),
        elevation: 0,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF81C3D7),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Teachers'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : TabBarView(
              controller: _tabController,
              children: [
                _StudentTab(totalStudents: _totalStudents),
                _TeacherTab(totalTeachers: _totalTeachers),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add',
        backgroundColor: const Color(0xFF81C3D7),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddUserPage()),
          ).then((_) => _fetchStats());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StudentTab extends StatelessWidget {
  final int totalStudents;
  const _StudentTab({required this.totalStudents});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildStatCard(
            'Total Students',
            totalStudents,
            Colors.blueAccent,
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Users')
                .where('role', isEqualTo: 'student')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No students found',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return _StudentReportCard(student: data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF546E7A),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherTab extends StatelessWidget {
  final int totalTeachers;
  const _TeacherTab({required this.totalTeachers});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildStatCard(
            'Total Teachers',
            totalTeachers,
            Colors.orangeAccent,
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Users')
                .where('role', isEqualTo: 'teacher')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No teachers found',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return Card(
                    color: const Color(0xFF4E585D),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade700,
                        child: Text(
                          (data['fullName'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        data['fullName'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        data['email'] ?? '',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: Text(
                        data['idNumber'] ?? '',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF546E7A),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentReportCard extends StatefulWidget {
  final Map<String, dynamic> student;
  const _StudentReportCard({required this.student});

  @override
  State<_StudentReportCard> createState() => _StudentReportCardState();
}

class _StudentReportCardState extends State<_StudentReportCard> {
  bool _expanded = false;
  List<Map<String, dynamic>> _sessionStats = [];
  bool _loadingStats = false;

  Future<void> _fetchSessionStats() async {
    if (_sessionStats.isNotEmpty) {
      setState(() => _expanded = !_expanded);
      return;
    }

    setState(() {
      _loadingStats = true;
      _expanded = true;
    });

    try {
      final sessionIds = List<String>.from(widget.student['sessionsId'] ?? []);
      final studentEmail = widget.student['email']?.toLowerCase();

      List<Map<String, dynamic>> stats = [];

      for (String sessionId in sessionIds) {
        final sessionDoc = await FirebaseFirestore.instance
            .collection('Sessions')
            .doc(sessionId)
            .get();
        if (!sessionDoc.exists) continue;

        final sessionName = sessionDoc['sessionsName'] ?? 'Unknown';

        final allAttendance = await FirebaseFirestore.instance
            .collection('Attendance')
            .where('sessionId', isEqualTo: sessionId)
            .get();

        final uniqueDates = allAttendance.docs
            .map((d) {
              final ts = d['markedAt'] as Timestamp?;
              return ts != null
                  ? DateTime(
                      ts.toDate().year,
                      ts.toDate().month,
                      ts.toDate().day,
                    )
                  : null;
            })
            .where((d) => d != null)
            .toSet();

        int totalClasses = uniqueDates.length;
        if (totalClasses == 0) totalClasses = 1;

        final studentAttendance = allAttendance.docs
            .where(
              (d) => d['email'] == studentEmail && d['status'] == 'present',
            )
            .length;

        double percentage = (studentAttendance / totalClasses) * 100;

        stats.add({
          'name': sessionName,
          'percentage': percentage,
          'present': studentAttendance,
          'total': totalClasses,
        });
      }

      if (mounted) {
        setState(() {
          _sessionStats = stats;
          _loadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF4E585D),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade700,
              child: Text(
                (widget.student['fullName'] ?? '?')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              widget.student['fullName'] ?? 'Unknown',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              widget.student['idNumber'] ?? '',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: IconButton(
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white,
              ),
              onPressed: _fetchSessionStats,
            ),
          ),
          if (_expanded)
            _loadingStats
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Column(
                    children: _sessionStats.map((stat) {
                      final pct = stat['percentage'] as double;
                      Color color = Colors.green;
                      if (pct < 50)
                        color = Colors.red;
                      else if (pct < 80)
                        color = Colors.orange;

                      return ListTile(
                        title: Text(
                          stat['name'],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: color),
                          ),
                          child: Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
        ],
      ),
    );
  }
}
