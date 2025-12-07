import 'package:flutter/material.dart';

/// Reusable dialog component for editing profile fields
class EditFieldDialog extends StatefulWidget {
  final String title;
  final String currentValue;
  final Function(String) onSave;

  const EditFieldDialog({
    Key? key,
    required this.title,
    required this.currentValue,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<EditFieldDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.title}'),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(labelText: widget.title),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onSave(_controller.text.trim());
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
