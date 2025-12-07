import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';
import '../config/email_config.dart';

class EmailService {
  static Future<bool> sendVerificationCode(String toEmail, String code) async {
    if (EmailConfig.senderEmail == 'your-email@gmail.com') {
      debugPrint(
        '⚠️ EMAIL NOT CONFIGURED: Please update lib/config/email_config.dart',
      );
      debugPrint('⚠️ SIMULATED EMAIL TO: $toEmail');
      debugPrint('⚠️ VERIFICATION CODE: $code');
      return true; // Return true for testing even if not configured
    }

    final smtpServer = gmail(EmailConfig.senderEmail, EmailConfig.appPassword);

    final message = Message()
      ..from = Address(EmailConfig.senderEmail, 'Attendance App')
      ..recipients.add(toEmail)
      ..subject = 'Device Verification Code'
      ..text =
          'Your verification code is: $code\n\nThis code will expire in 10 minutes.'
      ..html =
          '''
        <h1>Device Verification</h1>
        <p>Your verification code is:</p>
        <h2>$code</h2>
        <p>This code will expire in 10 minutes.</p>
      ''';

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('Message sent: ${sendReport.toString()}');
      return true;
    } catch (e) {
      debugPrint('Message not sent. \n${e.toString()}');
      return false;
    }
  }
}
