import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/session_data.dart';

class TeacherSessionCard extends StatelessWidget {
  final SessionData session;
  final bool isBroadcasting;
  final bool canMarkAttendance;
  final VoidCallback onToggleBroadcast;

  const TeacherSessionCard({
    Key? key,
    required this.session,
    required this.isBroadcasting,
    required this.canMarkAttendance,
    required this.onToggleBroadcast,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String startTimeStr = '';
    String endTimeStr = '';

    if (session.startTime != null) {
      final startDateTime = session.startTime!.toDate();
      startTimeStr = DateFormat('hh:mm a').format(startDateTime).toUpperCase();
    }

    if (session.endTime != null) {
      final endDateTime = session.endTime!.toDate();
      endTimeStr = DateFormat('hh:mm a').format(endDateTime).toUpperCase();
    }

    final isSessionActive = canMarkAttendance && !session.isCancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: session.isCancelled
            ? Colors.red.shade100
            : const Color(0xFFF5E6D3),
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
                if (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty)
                  SizedBox(
                    width: 70,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          startTimeStr,
                          style: TextStyle(
                            color: session.isCancelled
                                ? Colors.red
                                : const Color(0xFF2D3436),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: session.isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        Text(
                          endTimeStr,
                          style: TextStyle(
                            color: session.isCancelled
                                ? Colors.red
                                : const Color(0xFF2D3436),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            decoration: session.isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty)
                  const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: session.isCancelled
                        ? Colors.red
                        : const Color(0xFF8B4513),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      session.sessionTypeInitial,
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
                        '${session.id} ${session.sessionName}',
                        style: TextStyle(
                          color: session.isCancelled
                              ? Colors.red
                              : const Color(0xFF2D3436),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          decoration: session.isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (session.isCancelled)
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
                  Icons.location_on_outlined,
                  color: Color(0xFF636E72),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    session.physicalLocation,
                    style: const TextStyle(
                      color: Color(0xFF636E72),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (session.isLecture)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isSessionActive ? onToggleBroadcast : null,
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
                              session.isCancelled
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
}
