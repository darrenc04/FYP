import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:math';
import '../services/email_service.dart';

class DeviceLinkingPage extends StatefulWidget {
  const DeviceLinkingPage({Key? key}) : super(key: key);

  @override
  State<DeviceLinkingPage> createState() => _DeviceLinkingPageState();
}

class _DeviceLinkingPageState extends State<DeviceLinkingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  bool _isEnabled = false;
  String _currentDeviceId = '';
  String _linkedDeviceId = '';
  DateTime? _lastRemovedDate;
  bool _isLoading = true;
  // Remove the _canRemove variable as we're removing the 7-day cooldown

  @override
  void initState() {
    super.initState();
    _initDeviceLinking();
  }

  Future<void> _initDeviceLinking() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get current device ID
      _currentDeviceId = await _getDeviceId();

      // Load user's device linking data
      final docId = user.email!.toLowerCase();
      final doc = await _firestore.collection('Users').doc(docId).get();

      if (doc.exists) {
        final data = doc.data();
        final deviceToken = data?['deviceToken'] ?? '';

        // Safely handle lastDeviceRemoved which might be a String or Timestamp
        DateTime? lastRemovedDate;
        final lastRemovedRaw = data?['lastDeviceRemoved'];

        if (lastRemovedRaw is Timestamp) {
          lastRemovedDate = lastRemovedRaw.toDate();
        } else if (lastRemovedRaw is String && lastRemovedRaw.isNotEmpty) {
          // If it's a string, try to parse it or ignore it
          try {
            lastRemovedDate = DateTime.parse(lastRemovedRaw);
          } catch (_) {
            // Ignore invalid date strings
          }
        }

        setState(() {
          _linkedDeviceId = deviceToken;
          _isEnabled = deviceToken.isNotEmpty;
          _lastRemovedDate = lastRemovedDate;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error loading device linking: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id; // Unique Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? '';
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        return windowsInfo.deviceId;
      }
    } catch (e) {
      print('Error getting device ID: $e');
    }
    return '';
  }

  Future<bool> _verifyAction(String action) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;

    // 1. Generate Code
    final code = (Random().nextInt(900000) + 100000).toString();

    // 2. Send Email
    _showLoadingDialog('Sending verification code...');
    final sent = await EmailService.sendVerificationCode(user.email!, code);
    Navigator.pop(context); // Dismiss loading

    if (!sent) {
      _showErrorSnackBar(
        'Failed to send verification email. Check console/config.',
      );
      return false;
    }

    // 3. Show Verification Dialog
    final enteredCode = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String input = '';
        return AlertDialog(
          title: Text('Verify $action'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('A verification code has been sent to ${user.email}.'),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Enter 6-digit Code',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => input = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, input),
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );

    if (enteredCode == code) {
      return true;
    } else if (enteredCode != null) {
      _showErrorSnackBar('Invalid verification code');
    }
    return false;
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleDeviceLinking(bool value) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final docId = user.email!.toLowerCase();

      if (value) {
        // BINDING FLOW

        // 1. Confirm Dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bind Device'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Are you sure you want to bind this device?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  '• Email verification is required.',
                  style: TextStyle(fontSize: 13, color: Colors.blue),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Bind'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        // 1.5 Check if device is already linked to another account
        final querySnapshot = await _firestore
            .collection('Users')
            .where('deviceToken', isEqualTo: _currentDeviceId)
            .get();

        // Filter out the current user's doc if it happens to be there (though unlikely if we are binding)
        final otherUsers = querySnapshot.docs.where((doc) => doc.id != docId);

        if (otherUsers.isNotEmpty) {
          _showErrorSnackBar(
            'This device is already linked to another account. Please ask the other account to unbind it first.',
          );
          return;
        }

        // 2. Email Verification
        final verified = await _verifyAction('Binding');
        if (!verified) return;

        // 3. Perform Bind
        await _firestore.collection('Users').doc(docId).update({
          'deviceToken': _currentDeviceId,
        });

        setState(() {
          _isEnabled = true;
          _linkedDeviceId = _currentDeviceId;
        });

        _showSuccessSnackBar('Device successfully linked ✓');
      } else {
        // UNBINDING FLOW (Disable toggle)
        // Usually unbind is done via "Remove Device" button, but if toggle is used:
        await _removeDevice();
      }
    } catch (e) {
      _showErrorSnackBar('Error updating device linking: $e');
    }
  }

  Future<void> _removeDevice() async {
    // 1. Confirm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: const Text(
          'Are you sure you want to remove this device? You will need to verify via email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 2. Email Verification
    final verified = await _verifyAction('Unbinding');
    if (!verified) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final docId = user.email!.toLowerCase();
      await _firestore.collection('Users').doc(docId).update({
        'deviceToken': '',
        'lastDeviceRemoved': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isEnabled = false;
        _linkedDeviceId = '';
        _lastRemovedDate = DateTime.now();
      });

      _showSuccessSnackBar('Device removed successfully');
    } catch (e) {
      _showErrorSnackBar('Error removing device: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Device Binding',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Enable/Disable Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Device Binding',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        Switch(
                          value: _isEnabled,
                          // Remove the null check for _canRemove since we removed the 7-day cooldown
                          onChanged: _isEnabled ? null : _toggleDeviceLinking,
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),

                  // Success Message
                  if (_isEnabled && _linkedDeviceId == _currentDeviceId) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Device successfully linked to your account ✓',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Remove Device Button
                  // Remove the _canRemove check since we removed the 7-day cooldown
                  if (_isEnabled) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _removeDevice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // Remove disabled background color since we removed the 7-day cooldown
                      ),
                      child: const Text(
                        'Remove Device',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  // Reminder Box
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Reminder',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildBulletPoint(
                          'You can link your device to your account for secure attendance check-in.',
                        ),
                        _buildBulletPoint(
                          'Each device is identified by its unique ID and must be registered before use.',
                        ),
                        _buildBulletPoint(
                          'Only linked devices can be used for marking attendance.',
                        ),
                        _buildBulletPoint(
                          'One device can only be linked to one user account at a time.',
                          color: Colors.orange,
                        ),
                        _buildBulletPoint(
                          'Security: Email verification is required for binding and unbinding.',
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBulletPoint(String text, {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 16, color: color)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: color, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
