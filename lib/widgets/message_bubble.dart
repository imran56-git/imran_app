import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_sound/flutter_sound.dart';

class MessageBubble extends StatefulWidget {
  final String message;
  final bool isMe;
  final Timestamp? timestamp;
  final String messageId;
  final String type; // text / audio / image
  final bool isTyping;
  final VoidCallback? uploadVoiceMessage;

  /// optional extra fields for future use
  final bool isSeen;
  final bool isDelivered;
  final String? senderName;
  final String? replyText;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.timestamp,
    required this.messageId,
    required this.type,
    required this.isTyping,
    this.uploadVoiceMessage,
    this.isSeen = false,
    this.isDelivered = true,
    this.senderName,
    this.replyText,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  FlutterSoundPlayer? _player;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
  }

  @override
  void dispose() {
    _player?.closePlayer();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (widget.message.isEmpty) return;

    if (_isPlaying) {
      await _player?.stopPlayer();
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    } else {
      await _player?.startPlayer(
        fromURI: widget.message,
        whenFinished: () {
          if (mounted) {
            setState(() => _isPlaying = false);
          }
        },
      );
      if (mounted) {
        setState(() => _isPlaying = true);
      }
    }
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  bool get _isImageMessage {
    final lower = widget.message.toLowerCase();
    return widget.type == 'image' ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.startsWith('http') && (
          lower.contains('.png') ||
          lower.contains('.jpg') ||
          lower.contains('.jpeg') ||
          lower.contains('.webp')
        );
  }

  Widget _buildStatusIcon() {
    if (!widget.isMe) return const SizedBox.shrink();

    if (widget.isSeen) {
      return const Icon(
        Icons.done_all,
        size: 16,
        color: Colors.blue,
      );
    }

    if (widget.isDelivered) {
      return const Icon(
        Icons.done_all,
        size: 16,
        color: Colors.grey,
      );
    }

    return const Icon(
      Icons.done,
      size: 16,
      color: Colors.grey,
    );
  }

  void _showMessageActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy message'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copy action ready')),
                    );
                  },
                ),
                if (widget.isMe)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text(
                      'Delete message',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Delete action ready')),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview() {
    if (widget.replyText == null || widget.replyText!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withOpacity(0.35)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: widget.isMe ? Colors.white : const Color(0xFF128C7E),
            width: 4,
          ),
        ),
      ),
      child: Text(
        widget.replyText!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: widget.isMe ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextMessage() {
    return Text(
      widget.message,
      style: TextStyle(
        color: widget.isMe ? Colors.white : Colors.black87,
        fontSize: 15.5,
        height: 1.35,
      ),
    );
  }

  Widget _buildAudioMessage() {
    return InkWell(
      onTap: _toggleAudio,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor:
                widget.isMe ? Colors.white.withOpacity(0.18) : Colors.white,
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: widget.isMe ? Colors.white : const Color(0xFF128C7E),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 130,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isMe
                  ? Colors.white.withOpacity(0.45)
                  : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.mic,
            size: 18,
            color: widget.isMe ? Colors.white70 : Colors.grey.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context) {
    final isNetwork = widget.message.startsWith('http');
    final imageProvider = isNetwork
        ? NetworkImage(widget.message)
        : FileImage(File(widget.message)) as ImageProvider;

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(10),
            child: InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 230,
            maxHeight: 280,
          ),
          child: Image(
            image: imageProvider,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(
                width: 220,
                height: 180,
                color: Colors.grey.shade300,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image, size: 40),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (widget.type == 'audio') {
      return _buildAudioMessage();
    }

    if (_isImageMessage) {
      return _buildImageMessage(context);
    }

    return _buildTextMessage();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = widget.isMe
        ? const Color(0xFF0B93F6) // WhatsApp-like sent bubble
        : Colors.white;

    final textColor = widget.isMe ? Colors.white : Colors.black87;

    return Align(
      alignment:
          widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!widget.isMe && widget.isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
              child: Text(
                'typing...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          GestureDetector(
            onLongPress: () => _showMessageActions(context),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              padding: widget.type == 'image'
                  ? const EdgeInsets.all(6)
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
                  bottomRight: Radius.circular(widget.isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReplyPreview(),
                  DefaultTextStyle(
                    style: TextStyle(color: textColor),
                    child: _buildMessageContent(context),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(widget.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isMe
                              ? Colors.white70
                              : Colors.grey.shade600,
                        ),
                      ),
                      if (widget.isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}