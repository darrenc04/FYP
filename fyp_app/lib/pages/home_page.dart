import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = 'User';
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
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
          final sessionIds = List<String>.from(docSnap['sessionsId'] ?? []);
          
          // Fetch session details
          List<Map<String, dynamic>> sessions = [];
          for (String sessionId in sessionIds) {
            try {
              final sessionSnap = await FirebaseFirestore.instance
                  .collection('Sessions')
                  .doc(sessionId)
                  .get();
              
              if (sessionSnap.exists) {
                sessions.add({
                  'id': sessionId,
                  ...sessionSnap.data() as Map<String, dynamic>
                });
              }
            } catch (e) {
              debugPrint('Error fetching session \$sessionId: \$e');
            }
          }
          
          if (mounted) {
            setState(() {
              _userName = fullName;
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
      debugPrint('Error fetching user data: \$e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF49555B);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: user info + actions
              Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black26,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                    icon: const Icon(Icons.settings, color: Colors.white),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // Title row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Today's classes",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF3F4A4E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Session cards list
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _sessions.isEmpty
                        ? const Center(
                            child: Text(
                              'No sessions assigned',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _sessions.length,
                            itemBuilder: (context, index) {
                              final session = _sessions[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFFE6B0A6),
                                      child: Text(
                                        (session['sessionsType'] ?? '?')
                                            .toString()
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${session['id']} ${session['sessionsName'] ?? 'Session'} ',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on,
                                                  size: 16,
                                                  color: Colors.black54),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  session['location'] ??
                                                      'Location TBD',
                                                  style: const TextStyle(
                                                      color: Colors.black54),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.person,
                                                  size: 16,
                                                  color: Colors.black54),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '${session['lecturerName'] ?? 'N/A'}',
                                                  style: const TextStyle(
                                                      color: Colors.black54),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            side: const BorderSide(
                                                color: Color(0xFF2E7DFF)),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () {},
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 6,
                                            ),
                                            child: Text(
                                              'Mark\nAttendance',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Color(0xFF2E7DFF),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
