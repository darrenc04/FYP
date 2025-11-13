import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

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
  bool _canRemove = true;

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

          // Check if one week has passed since last removal
          if (_lastRemovedDate != null) {
            final daysSinceRemoval = DateTime.now()
                .difference(_lastRemovedDate!)
                .inDays;
            _canRemove = daysSinceRemoval >= 7;
          }
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
      }
    } catch (e) {
      print('Error getting device ID: $e');
    }
    return '';
  }

  Future<void> _toggleDeviceLinking(bool value) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final docId = user.email!.toLowerCase();

      if (value) {
        // Check if this device is already linked to another user
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

        // Link device
        await _firestore.collection('Users').doc(docId).update({
          'deviceToken': _currentDeviceId,
        });

        setState(() {
          _isEnabled = true;
          _linkedDeviceId = _currentDeviceId;
        });

        _showSuccessSnackBar('Device successfully linked to your account ✓');
      } else {
        // Disable (not remove)
        await _firestore.collection('Users').doc(docId).update({
          'deviceToken': '',
        });

        setState(() {
          _isEnabled = false;
          _linkedDeviceId = '';
        });

        _showSuccessSnackBar('Device linking disabled');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating device linking: $e');
    }
  }

  Future<void> _removeDevice() async {
    if (!_canRemove) {
      final daysLeft = 7 - DateTime.now().difference(_lastRemovedDate!).inDays;
      _showErrorSnackBar('You can remove device again in $daysLeft day(s)');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: const Text(
          'Are you sure you want to remove this device? You can only remove a device once per week.',
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
        _canRemove = false;
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
                  if (_isEnabled) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _canRemove ? _removeDevice : null,
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
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: Text(
                        _canRemove
                            ? 'Remove Device'
                            : 'Remove Device (Available in ${7 - DateTime.now().difference(_lastRemovedDate!).inDays} days)',
                        style: const TextStyle(
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
                          'After removing a device, you must wait 7 days before you can remove it again to prevent frequent device changes.',
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
