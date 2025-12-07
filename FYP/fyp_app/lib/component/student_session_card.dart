import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/session_data.dart';

class StudentSessionCard extends StatelessWidget {
  final SessionData session;
  final bool canMarkAttendance;
  final VoidCallback onMarkAttendance;
  final VoidCallback? onRevocationTap;

  const StudentSessionCard({
    Key? key,
    required this.session,
    required this.canMarkAttendance,
    required this.onMarkAttendance,
    this.onRevocationTap,
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
                  Icons.person_outline,
                  color: Color(0xFF636E72),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    session.lecturerName ?? 'Unknown',
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
            const SizedBox(height: 4),
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
                // Action Button
                if (session.isCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy, color: Colors.red, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Cancelled',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (session.attendanceRevoked)
                  ElevatedButton(
                    onPressed: onRevocationTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Absent',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (session.attendanceMarked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B894).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00B894),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF00B894),
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Marked',
                          style: TextStyle(
                            color: Color(0xFF00B894),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: isSessionActive ? onMarkAttendance : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSessionActive
                          ? const Color(0xFF4A9FE8)
                          : Colors.grey.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Mark Attendance',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
