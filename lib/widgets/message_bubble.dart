import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String messageId;
  final String currentUserId;
  final void Function(String messageId, String oldMessage) onEdit;

  const MessageBubble({
    required this.message,
    required this.isMe,
    required this.messageId,
    required this.currentUserId,
    required this.onEdit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (isMe)
              IconButton(
                icon: const Icon(Icons.edit, size: 16),
                onPressed: () => onEdit(messageId, message),
              ),
          ],
        ),
      ),
    );
  }
}