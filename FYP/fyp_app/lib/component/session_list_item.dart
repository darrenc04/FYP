import 'package:flutter/material.dart';
import '../model/teacher_dashboard_data.dart';

/// Reusable session list item component
class SessionListItem extends StatelessWidget {
  final SessionStat sessionStat;
  final VoidCallback onTap;

  const SessionListItem({
    Key? key,
    required this.sessionStat,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCancelled = sessionStat.isCancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isCancelled
            ? Colors.red.withOpacity(0.2)
            : const Color(0xFF546E7A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: isCancelled
            ? Border.all(color: Colors.red.withOpacity(0.5))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.book, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sessionStat.name,
                        style: TextStyle(
                          color: isCancelled ? Colors.redAccent : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (isCancelled)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Session Cancelled',
                            style: TextStyle(
                              color: Colors.redAccent.shade100,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        sessionStat.code,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${sessionStat.percentage.toStringAsFixed(0)}% Present',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${sessionStat.present}/${sessionStat.totalStudents} Students',
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
  }
}
