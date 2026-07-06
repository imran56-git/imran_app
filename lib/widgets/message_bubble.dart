import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

class MessageBubble extends StatefulWidget {
  final String message;
  final bool isMe;
  final Timestamp? timestamp;
  final String messageId;
  final String type;
  final bool isTyping;
  final VoidCallback uploadVoiceMessage;
  final bool isSeen;
  final bool isDelivered;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.timestamp,
    required this.messageId,
    required this.type,
    required this.isTyping,
    required this.uploadVoiceMessage,
    this.isSeen = false,
    this.isDelivered = true,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  late final AudioPlayer _audioPlayer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    });
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  Future<void> _toggleAudio() async {
    if (widget.message.trim().isEmpty) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(widget.message));
        if (mounted) {
          setState(() => _isPlaying = true);
        }
      }
    } catch (e) {
      debugPrint('Audio play error: $e');
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
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

  Widget _buildAudioBubble() {
    return InkWell(
      onTap: _toggleAudio,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF128C7E),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 110,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.mic,
            size: 18,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        widget.isMe ? const Color(0xFFDCF8C6) : Colors.white;

    return Align(
      alignment:
          widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!widget.isMe && widget.isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Text(
                'Typing...',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
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
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.type == 'audio'
                    ? _buildAudioBubble()
                    : Text(
                        widget.message,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(widget.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
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
        ],
      ),
    );
  }
}