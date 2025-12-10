import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/attendance_record.dart';

class AttendanceHistoryCard extends StatelessWidget {
  final AttendanceRecord record;

  const AttendanceHistoryCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final sessionDateStr = record.sessionDate;

    String dateStr = 'N/A';
    if (sessionDateStr != null && sessionDateStr.isNotEmpty) {
      try {
        final parsedDate = DateFormat('yyyy-MM-dd').parse(sessionDateStr);
        dateStr = DateFormat('dd MMM yyyy').format(parsedDate);
      } catch (e) {
        dateStr = sessionDateStr;
      }
    } else if (record.markedAt != null) {
      dateStr = DateFormat('dd MMM yyyy').format(record.markedAt!.toDate());
    }

    final startTimeStr = record.startTime != null
        ? DateFormat('hh:mm a').format(record.startTime!.toDate())
        : 'N/A';
    final endTimeStr = record.endTime != null
        ? DateFormat('hh:mm a').format(record.endTime!.toDate())
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
          // Date and Session Type on same line
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 12, color: Color(0xFF636E72)),
              ),
              const Spacer(),
              if (record.sessionType.isNotEmpty)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getSessionTypeColor(record.sessionType),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      _getSessionTypeInitial(record.sessionType),
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
              Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
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
              if (record.isAbsent)
                const Text(
                  'Absent',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else ...[
                Icon(
                  _getVerificationIcon(record.verificationMethod),
                  size: 14,
                  color: Colors.green,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _getVerificationLabel(record.verificationMethod),
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ],
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
    return 'P';
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
