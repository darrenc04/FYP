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
        final lastRemoved = data?['lastDeviceRemoved'] as Timestamp?;

        setState(() {
          _linkedDeviceId = deviceToken;
          _isEnabled = deviceToken.isNotEmpty;
          _lastRemovedDate = lastRemoved?.toDate();
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

  // Check if device has performed an action in the last 24 hours
  Future<bool> _checkDeviceRestriction(String deviceId) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      final logs = await _firestore
          .collection('DeviceLogs')
          .where('deviceId', isEqualTo: deviceId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .get();

      // If there are any logs in the last 24 hours, restrict action
      return logs.docs.isEmpty;
    } catch (e) {
      debugPrint('Error checking device restriction: $e');
      // IMPORTANT: If it's a missing index error, we want to know!
      // Don't just block the user silently.
      if (e.toString().contains('failed-precondition')) {
        _showErrorSnackBar('Missing Database Index. Check console for link.');
        throw e; // Re-throw to stop execution but let the user know
      }
      _showErrorSnackBar(
        'Error checking limit: ${e.toString().split(']').last.trim()}',
      );
      return false; // Fail safe: block if error
    }
  }

  Future<void> _logDeviceAction(
    String deviceId,
    String action,
    String email,
  ) async {
    try {
      await _firestore.collection('DeviceLogs').add({
        'deviceId': deviceId,
        'action': action, // 'bind' or 'unbind'
        'email': email,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging device action: $e');
    }
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

        // 1. Check Restriction FIRST (Save user time)
        final canAct = await _checkDeviceRestriction(_currentDeviceId);
        if (!canAct) {
          _showErrorSnackBar(
            'This device has reached its daily limit (1 action/day).',
          );
          return;
        }

        // 2. Confirm Dialog
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
                  '• 1 action per device per day limit applies.',
                  style: TextStyle(fontSize: 13, color: Colors.red),
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

        // 3. Email Verification
        final verified = await _verifyAction('Binding');
        if (!verified) return;

        // 4. Check if device linked to another user
        final existingDevice = await _firestore
            .collection('Users')
            .where('deviceToken', isEqualTo: _currentDeviceId)
            .get();

        if (existingDevice.docs.isNotEmpty &&
            existingDevice.docs.first.id != docId) {
          _showErrorSnackBar(
            'This device is already linked to another account',
          );
          return;
        }

        // 5. Perform Bind
        await _firestore.collection('Users').doc(docId).update({
          'deviceToken': _currentDeviceId,
        });

        // 6. Log Action
        await _logDeviceAction(_currentDeviceId, 'bind', user.email!);

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
    // Remove the 7-day cooldown check since we have daily limits

    // 1. Check Restriction
    final canAct = await _checkDeviceRestriction(_currentDeviceId);
    if (!canAct) {
      _showErrorSnackBar(
        'This device has reached its daily limit (1 action/day).',
      );
      return;
    }

    // 2. Confirm
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

    // 3. Email Verification
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

      // 4. Log Action
      await _logDeviceAction(_currentDeviceId, 'unbind', user.email!);

      setState(() {
        _isEnabled = false;
        _linkedDeviceId = '';
        _lastRemovedDate = DateTime.now();
        // Remove _canRemove as we're removing the 7-day cooldown
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
                        // Update this bullet point to reflect the removal of the 7-day cooldown
                        _buildBulletPoint(
                          'Security: Email verification is required for binding and unbinding.',
                          color: Colors.blue,
                        ),
                        _buildBulletPoint(
                          'Restriction: A device can only perform 1 bind/unbind action per day.',
                          color: Colors.red,
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
