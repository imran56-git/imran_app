import 'package:flutter/material.dart';

class DeleteChatDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const DeleteChatDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        'Delete Conversation',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
      ),
      content: const Text(
        'Are you sure you want to delete this entire conversation? All messages will be permanently removed.',
        style: TextStyle(
          fontSize: 14,
          color: Colors.black54,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
