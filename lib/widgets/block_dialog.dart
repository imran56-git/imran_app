import 'package:flutter/material.dart';

class BlockDialog extends StatefulWidget {
  final String userName;
  final Future<void> Function() onConfirm;

  const BlockDialog({
    super.key,
    required this.userName,
    required this.onConfirm,
  });

  @override
  State<BlockDialog> createState() => _BlockDialogState();
}

class _BlockDialogState extends State<BlockDialog> {
  bool _isLoading = false;

  Future<void> _handleBlock() async {
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
          SnackBar(content: Text('Failed to block user: $e')),
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
        'Block User',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.redAccent,
        ),
      ),
      content: Text(
        'Are you sure you want to block ${widget.userName}? You will no longer receive messages or calls from this user.',
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
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
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _isLoading ? null : _handleBlock,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Block', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
