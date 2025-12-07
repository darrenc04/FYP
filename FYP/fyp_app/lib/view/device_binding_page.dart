import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/device_linking.dart';
import '../controller/device_linking_controller.dart';
import '../component/deviceBinding/device_binding_toggle.dart';
import '../component/device_linked_success_message.dart';
import '../component/deviceBinding/device_binding_reminder_box.dart';

class DeviceLinkingPage extends StatefulWidget {
  const DeviceLinkingPage({Key? key}) : super(key: key);

  @override
  State<DeviceLinkingPage> createState() => _DeviceLinkingPageState();
}

class _DeviceLinkingPageState extends State<DeviceLinkingPage> {
  final DeviceLinkingController _controller = DeviceLinkingController();

  bool _isEnabled = false;
  String _currentDeviceId = '';
  String _linkedDeviceId = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initDeviceLinking();
  }

  Future<void> _initDeviceLinking() async {
    try {
      final deviceLinking = await _controller.loadDeviceLinkingData();

      setState(() {
        _isEnabled = deviceLinking.isEnabled;
        _currentDeviceId = deviceLinking.currentDeviceId;
        _linkedDeviceId = deviceLinking.linkedDeviceId;
      });
    } catch (e) {
      _showErrorSnackBar('Error loading device linking: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _verifyAction(String action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;

    // 1. Generate Code
    final code = _controller.generateVerificationCode();

    // 2. Send Email
    _showLoadingDialog('Sending verification code...');
    final sent = await _controller.sendVerificationEmail(user.email!, code);
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
        final isLinked = await _controller.checkDeviceAlreadyLinked(
          _currentDeviceId,
        );

        if (isLinked) {
          _showErrorSnackBar(
            'This device is already linked to another account. Please ask the other account to unbind it first.',
          );
          return;
        }

        // 2. Email Verification
        final verified = await _verifyAction('Binding');
        if (!verified) return;

        // 3. Perform Bind
        await _controller.bindDevice(_currentDeviceId);

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
      await _controller.unbindDevice();

      setState(() {
        _isEnabled = false;
        _linkedDeviceId = '';
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
                  DeviceBindingToggle(
                    isEnabled: _isEnabled,
                    onChanged: _isEnabled ? null : _toggleDeviceLinking,
                  ),

                  // Success Message
                  if (_isEnabled && _linkedDeviceId == _currentDeviceId) ...[
                    const SizedBox(height: 16),
                    const DeviceLinkedSuccessMessage(),
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
                  const DeviceBindingReminderBox(),
                ],
              ),
            ),
    );
  }
}
