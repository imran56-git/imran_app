import 'package:flutter/material.dart';

class ReplyMessageWidget extends StatelessWidget {
  final String messageSenderName;
  final String messageText;
  final String messageType;
  final VoidCallback? onCancelReply;

  const ReplyMessageWidget({
    super.key,
    required this.messageSenderName,
    required this.messageText,
    required this.messageType,
    this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(25),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              color: const Color(0xFF00A884),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    messageSenderName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00A884),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    messageType == 'text' ? messageText : '[$messageType]',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onCancelReply != null)
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                onPressed: onCancelReply,
              ),
          ],
        ),
      ),
    );
  }
}
