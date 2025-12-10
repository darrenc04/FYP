import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controller/timetable_controller.dart';
import '../model/session_data.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage>
    with SingleTickerProviderStateMixin {
  final TimetableController _controller = TimetableController();
  late TabController _tabController;

  // Cache for loaded weeks
  final Map<int, Map<String, List<SessionData>>> _weekCache = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadWeekData(1); // Load Week 1 initially
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      // indexIsChanging is true when clicking a tab
      _loadWeekData(_tabController.index + 1);
    } else if (!_tabController.indexIsChanging &&
        _tabController.animation?.value == _tabController.index.toDouble()) {
      // This catches swipe completion
      _loadWeekData(_tabController.index + 1);
    }
  }

  Future<void> _loadWeekData(int weekIndex) async {
    if (_weekCache.containsKey(weekIndex)) {
      if (mounted) setState(() {});
      return;
    }

    setState(() => _isLoading = true);
    final data = await _controller.fetchSessionsForWeek(weekIndex);
    if (mounted) {
      setState(() {
        _weekCache[weekIndex] = data;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3D4A4F),
      appBar: AppBar(
        title: const Text('Timetable', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF3D4A4F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF81C3D7),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF81C3D7),
          tabs: List.generate(7, (index) => Tab(text: 'Week ${index + 1}')),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(7, (index) {
          final weekNum = index + 1;
          if (_isLoading && !_weekCache.containsKey(weekNum)) {
            return const Center(child: CircularProgressIndicator());
          }
          final weekData = _weekCache[weekNum] ?? {};
          return _buildWeekView(weekData, weekNum);
        }),
      ),
    );
  }

  Widget _buildWeekView(Map<String, List<SessionData>> weekData, int weekNum) {
    if (weekData.isEmpty) {
      return const Center(
        child: Text(
          'No sessions found',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Sort dates
    final sortedDates = weekData.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateStr = sortedDates[index];
        final sessions = weekData[dateStr] ?? [];
        final date = DateTime.parse(dateStr);
        final dayName = DateFormat('EEEE').format(date);
        final formattedDate = DateFormat('MMM d').format(date);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    dayName,
                    style: const TextStyle(
                      color: Color(0xFF81C3D7),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (sessions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No classes',
                  style: TextStyle(color: Colors.white38),
                ),
              )
            else
              ...sessions.map((session) => _buildSessionCard(session)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildSessionCard(SessionData session) {
    final startTime = session.startTime != null
        ? DateFormat('h:mm a').format(session.startTime!.toDate())
        : 'Unknown';
    final endTime = session.endTime != null
        ? DateFormat('h:mm a').format(session.endTime!.toDate())
        : 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: session.isCancelled
              ? Colors.red.withOpacity(0.5)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Time Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                startTime,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF333333),
                ),
              ),
              Container(
                height: 16,
                width: 2,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
              Text(
                endTime,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: session.isLecture
                            ? const Color(0xFFE3F2FD)
                            : const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        session.sessionType,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: session.isLecture
                              ? const Color(0xFF1565C0)
                              : const Color(0xFF7B1FA2),
                        ),
                      ),
                    ),
                    if (session.isCancelled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50], // Very light red
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: const Text(
                          'CANCELLED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  session.sessionName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF333333),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${session.courseCode} • ${session.physicalLocation} • ${session.lecturerName ?? "No Lecturer"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
