import 'package:flutter/material.dart';

class DeleteChatDialog extends StatefulWidget {
  final Future<void> Function() onConfirm;

  const DeleteChatDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  State<DeleteChatDialog> createState() => _DeleteChatDialogState();
}

class _DeleteChatDialogState extends State<DeleteChatDialog> {
  bool _isLoading = false;

  Future<void> _handleDelete() async {
    setState(() => _isLoading = true);
    try {
      await widget.onConfirm();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete conversation: $e')),
        );
      }
    }
  }

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
          onPressed: _isLoading ? null : () => Navigator.pop(context),
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
          onPressed: _isLoading ? null : _handleDelete,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
