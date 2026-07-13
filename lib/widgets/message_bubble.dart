import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/message_model.dart'; // আপনার ডিরেক্টরি অনুযায়ী মডেল পাথ
import '../widgets/success_toast.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message; // আলাদা প্যারামিটার বাদ দিয়ে অবজেক্ট সিঙ্ক করা হলো
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
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
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  Future<void> _toggleAudio() async {
    if (widget.message.content.trim().isEmpty) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(widget.message.content));
        if (mounted) setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint('Audio play error: $e');
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  // হোয়াটসঅ্যাপ স্টাইল ব্লু-টিক / সেন্ট টিক ইন্ডিকেটর
  Widget _buildStatusIcon() {
    if (!widget.isMe) return const SizedBox.shrink();
    final status = widget.message.status.toLowerCase();

    if (status == 'seen' || status == 'read') {
      return const Icon(Icons.done_all, size: 16, color: Colors.blue);
    }
    if (status == 'delivered') {
      return const Icon(Icons.done_all, size: 16, color: Colors.grey);
    }
    return const Icon(Icons.done, size: 16, color: Colors.grey);
  }

  // ১. ভয়েস মেসেজ বাবল লেআউট
  Widget _buildAudioBubble() {
    return InkWell(
      onTap: _toggleAudio,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF006653),
            child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Container(
            width: 120, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(width: 8),
          Icon(Icons.mic, size: 18, color: widget.isMe ? Colors.black54 : Colors.grey),
        ],
      ),
    );
  }

  // ২. ইমেজ মেসেজ বাবল লেআউট
  Widget _buildImageBubble() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        widget.message.content,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 200, height: 200,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      ),
    );
  }

  // ৩. ডকুমেন্ট মেসেজ বাবল লেআউট (PDF, DOCX, APK) - টাইপো ফিক্সড
  Widget _buildDocumentBubble() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_rounded, color: Colors.redAccent, size: 32),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Document File", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)), // blackDE ফিক্সড
                SizedBox(height: 2),
                Text("Tap to view / download", style: TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.download_for_offline_rounded, color: Color(0xFF006653)), onPressed: () {})
        ],
      ),
    );
  }

  // লং-প্রেস অ্যাকশন পপআপ মেনু ইঞ্জিন
  void _showLongPressMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.message.type == 'text')
              ListWhiteTiles(
                leading: const Icon(Icons.copy_rounded, color: Colors.black87),
                title: const Text('Copy Text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.message.content));
                  Navigator.pop(context);
                  SuccessToast.show(context, "Copied to Clipboard");
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.black87),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete for Me', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              title: const Text('Delete for Everyone', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = widget.isMe ? const Color(0xFFE7FFDB) : Colors.white; 
    final msgType = widget.message.type.toLowerCase();

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showLongPressMenu(context), 
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
              bottomRight: Radius.circular(widget.isMe ? 4 : 16),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msgType == 'audio' || msgType == 'voice')
                _buildAudioBubble()
              else if (msgType == 'image')
                _buildImageBubble()
              else if (msgType == 'document' || msgType == 'file')
                _buildDocumentBubble()
              else
                Text(widget.message.content, style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.25)), // blackDE ফিক্সড

              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  Text(
                    _formatTime(widget.message.timestamp),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
    );
  }
}

// লিস্ট ভিউ বা পপআপ মেনু সাপোর্টের জন্য হেল্পার উইজেট
class ListWhiteTiles extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final VoidCallback onTap;

  const ListWhiteTiles({super.key, required this.leading, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: leading, title: title, onTap: onTap);
  }
}
