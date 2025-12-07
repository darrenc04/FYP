import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Reusable date selector component for dashboard
class DashboardDateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onDateTap;

  const DashboardDateSelector({
    Key? key,
    required this.selectedDate,
    required this.onDateTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onDateTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              DateFormat('EEEE, MMM dd, yyyy').format(selectedDate),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.white70, size: 22),
          ],
        ),
      ),
    );
  }
}
