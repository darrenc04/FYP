import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class InsertTestDataPage extends StatefulWidget {
  const InsertTestDataPage({Key? key}) : super(key: key);

  @override
  State<InsertTestDataPage> createState() => _InsertTestDataPageState();
}

class _InsertTestDataPageState extends State<InsertTestDataPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isInserting = false;
  String _status = '';
  int _insertedCount = 0;
  List<String> _existingSessions = [];

  @override
  void initState() {
    super.initState();
    _loadExistingSessions();
  }

  Future<void> _loadExistingSessions() async {
    try {
      final snapshot = await _firestore.collection('Sessions').get();
      setState(() {
        _existingSessions = snapshot.docs.map((doc) => doc.id).toList();
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error loading sessions: $e';
      });
    }
  }

  Future<void> _insertRandomRecords(int numRecords) async {
    if (_existingSessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No existing sessions found!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isInserting = true;
      _status = 'Inserting $numRecords records...';
      _insertedCount = 0;
    });

    try {
      final today = DateTime.now();
      final random = Random();

      for (int i = 0; i < numRecords; i++) {
        // Pick random existing session
        final sessionId = _existingSessions[random.nextInt(_existingSessions.length)];

        // Generate random date (1-30 days from now)
        final daysOffset = random.nextInt(30) + 1;
        final date = today.add(Duration(days: daysOffset));
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        // Get the existing session data to use as template
        final sessionDoc = await _firestore.collection('Sessions').doc(sessionId).get();
        
        if (!sessionDoc.exists) {
          continue;
        }

        final sessionData = sessionDoc.data() as Map<String, dynamic>;

        // Prepare data using existing session info
        final data = {
          'end_time': Timestamp.fromDate(
            DateTime(date.year, date.month, date.day, 23, 59, 59),
          ),
          'frequencyGeneratedAt': Timestamp.now(),
          'isCancelled': random.nextBool(),
          'lecturerName': sessionData['lecturerName'] ?? 'Unknown',
          'location': sessionData['location'] ?? GeoPoint(0, 0),
          'physicalLocation': sessionData['physicalLocation'] ?? 'Unknown',
          'sessionsName': sessionData['sessionsName'] ?? 'Session',
          'sessionsType': sessionData['sessionsType'] ?? 'Class',
          'start_time': Timestamp.fromDate(
            DateTime(date.year, date.month, date.day, 12, 0, 0),
          ),
          'targetFrequency': 18000 + (random.nextInt(21) * 100),
        };

        // Insert into existing session's subcollection
        await _firestore
            .collection('Sessions')
            .doc(sessionId)
            .collection(dateStr)
            .doc('session_info')
            .set(data);

        setState(() {
          _insertedCount = i + 1;
          _status = 'Inserted $_insertedCount/$numRecords records...';
        });
      }

      setState(() {
        _status = '✅ Successfully inserted $numRecords records!';
        _isInserting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Inserted $_insertedCount records successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isInserting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insert Test Data'),
        backgroundColor: Colors.blue[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.storage,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Insert Random Session Records',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Found ${_existingSessions.length} existing sessions',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (_existingSessions.isNotEmpty)
              Text(
                _existingSessions.join(', '),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 32),
            if (_isInserting)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _status,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            else
              Column(
                children: [
                  if (_status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Text(
                        _status,
                        style: TextStyle(
                          fontSize: 16,
                          color: _status.contains('✅') ? Colors.green : Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: _existingSessions.isEmpty ? null : () => _insertRandomRecords(5),
                    icon: const Icon(Icons.add),
                    label: const Text('Add 5 Records'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      backgroundColor: Colors.blue[800],
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _existingSessions.isEmpty ? null : () => _insertRandomRecords(10),
                    icon: const Icon(Icons.add),
                    label: const Text('Add 10 Records'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      backgroundColor: Colors.green[800],
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _existingSessions.isEmpty ? null : () => _insertRandomRecords(20),
                    icon: const Icon(Icons.add),
                    label: const Text('Add 20 Records'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      backgroundColor: Colors.orange[800],
                      disabledBackgroundColor: Colors.grey,
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
