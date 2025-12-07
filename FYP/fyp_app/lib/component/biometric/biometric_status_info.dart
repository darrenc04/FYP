import 'package:flutter/material.dart';

class BiometricStatusInfo extends StatelessWidget {
  final bool isEnabled;
  final bool isFaceVerified;
  final bool isFingerprintVerified;

  const BiometricStatusInfo({
    super.key,
    required this.isEnabled,
    required this.isFaceVerified,
    required this.isFingerprintVerified,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFullyVerified = isFaceVerified && isFingerprintVerified;
    final Color statusColor = isEnabled
        ? (isFullyVerified ? Colors.green : Colors.orange)
        : Colors.orange;

    final IconData statusIcon = isEnabled
        ? (isFullyVerified ? Icons.check_circle : Icons.warning_amber)
        : Icons.info_outline;

    final String statusTitle = _getStatusTitle();
    final String statusDescription = _getStatusDescription();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor.withOpacity(0.9),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusTitle() {
    if (!isEnabled) return 'Biometric Disabled';
    if (isFaceVerified && isFingerprintVerified) {
      return 'Biometric Active (Face & Fingerprint)';
    }
    if (isFaceVerified && !isFingerprintVerified) {
      return 'Face Verified - Fingerprint Pending';
    }
    if (!isFaceVerified && isFingerprintVerified) {
      return 'Fingerprint Verified - Face Pending';
    }
    return 'Registration Pending';
  }

  String _getStatusDescription() {
    if (!isEnabled) return 'Biometric verification is disabled';
    if (isFaceVerified && isFingerprintVerified) {
      return 'Face & Fingerprint verified. Ready for attendance.';
    }
    return 'Please complete all biometric registrations';
  }
}
