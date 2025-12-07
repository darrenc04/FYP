import 'package:flutter/material.dart';

/// Reusable dialog component for changing password
class ChangePasswordDialog extends StatefulWidget {
  final Future<void> Function(String oldPassword, String newPassword)
  onChangePassword;

  const ChangePasswordDialog({Key? key, required this.onChangePassword})
    : super(key: key);

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    super.dispose();
  }

  void _handleChangePassword(BuildContext context) async {
    Navigator.pop(context);
    try {
      await widget.onChangePassword(
        _oldPassController.text,
        _newPassController.text,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error changing password: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _oldPassController,
            decoration: const InputDecoration(labelText: 'Current Password'),
            obscureText: true,
          ),
          TextField(
            controller: _newPassController,
            decoration: const InputDecoration(labelText: 'New Password'),
            obscureText: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => _handleChangePassword(context),
          child: const Text('Change'),
        ),
      ],
    );
  }
}
