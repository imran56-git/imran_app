import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message_model.dart'; 
import '../services/chat_service.dart';
import '../widgets/success_toast.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message; 
  final bool isMe;
  final String chatRoomId;
  final String currentUserId;
  final Function(MessageModel) onReplyPressed; 

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.chatRoomId,
    required this.currentUserId,
    required this.onReplyPressed,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  late final AudioPlayer _audioPlayer;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;

  final ChatService _chatService = ChatService();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudioListeners();
  }

  void _initAudioListeners() {
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? date) {
    if (date == null) return ''; 
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  // 🔴 ১০ মিনিটের বেশি হয়েছে কিনা এবং মেসেজটি নিজের ও টেক্সট টাইপ কিনা চেক করার লজিক 🔴
  bool _canEditMessage() {
    if (!widget.isMe) return false;
    if (widget.message.type.toLowerCase() != 'text') return false;
    if (widget.message.isDeletedForEveryone) return false;
    if (widget.message.timestamp == null) return false;

    final messageTime = widget.message.timestamp!;
    final currentTime = DateTime.now();
    final difference = currentTime.difference(messageTime);

    return difference.inMinutes < 10;
  }

  // 🔴 মেসেজ এডিট করার ডায়ালগ পপ-আপ 🔴
  void _showEditDialog(BuildContext context) {
    final TextEditingController editController = TextEditingController(text: widget.message.content);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: editController,
            maxLines: null,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Edit your message...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E4C7A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final newText = editController.text.trim();
                if (newText.isNotEmpty && newText != widget.message.content) {
                  Navigator.pop(dialogContext);
                  try {
                    // ChatService-এ মেসেজ আপডেট ফায়ারবেস ট্রানজেকশন
                    await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(widget.chatRoomId)
                        .collection('messages')
                        .doc(widget.message.messageId)
                        .update({'content': newText, 'isEdited': true});
                    
                    if (context.mounted) {
                      SuccessToast.show(context, "Message edited");
                    }
                  } catch (e) {
                    debugPrint('Error editing message: $e');
                  }
                } else {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleAudio() async {
    if (widget.message.content.trim().isEmpty) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(UrlSource(widget.message.content));
      }
    } catch (e) {
      debugPrint('Audio play error: $e');
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Widget _buildStatusIcon() {
    if (!widget.isMe) return const SizedBox.shrink();
    final status = widget.message.status.toLowerCase();

    if (status == 'seen' || status == 'read') {
      return const Icon(Icons.done_all, size: 16, color: Color(0xFF34B7F1));
    }
    if (status == 'delivered') {
      return const Icon(Icons.done_all, size: 16, color: Colors.grey);
    }
    return const Icon(Icons.done, size: 14, color: Colors.grey);
  }

  Widget _buildAudioBubble() {
    return InkWell(
      onTap: _toggleAudio,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF1E4C7A),
              child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    value: _duration.inMilliseconds > 0 
                        ? _position.inMilliseconds / _duration.inMilliseconds 
                        : 0.0,
                    backgroundColor: Colors.grey.shade300,
                    color: const Color(0xFF1E4C7A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPlaying
                      ? "${_position.inSeconds}s / ${_duration.inSeconds}s"
                      : "Voice Message",
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.mic, size: 18, color: widget.isMe ? Colors.black54 : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBubble() {
    return GestureDetector(
      onTap: () => _openUrl(widget.message.content),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          widget.message.content,
          width: 220,
          height: 200,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 220,
              height: 200,
              color: Colors.grey.shade200,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  color: const Color(0xFF1E4C7A),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            width: 220, 
            height: 200,
            color: Colors.grey.shade200,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
                SizedBox(height: 4),
                Text("Failed to load image", style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentBubble() {
    final fileName = widget.message.mediaMetaData?['fileName'] ?? "Document File";
    return InkWell(
      onTap: () => _openUrl(widget.message.content),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_rounded, color: Colors.redAccent, size: 32),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName, 
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  const Text("Tap to view / download", style: TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.download_for_offline_rounded, color: Color(0xFF1E4C7A), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBubble() {
    return InkWell(
      onTap: () => _openUrl("https://www.google.com/maps/search/?api=1&query=${widget.message.content}"),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 32),
            const SizedBox(width: 10),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Shared Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                  SizedBox(height: 2),
                  Text("Tap to open in Map", style: TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.open_in_new_rounded, color: Colors.grey.shade600, size: 18),
          ],
        ),
      ),
    );
  }

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
            if (widget.message.type == 'text' && !widget.message.isDeletedForEveryone)
              ListWhiteTiles(
                leading: const Icon(Icons.copy_rounded, color: Colors.black87),
                title: const Text('Copy Text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.message.content));
                  Navigator.pop(context);
                  SuccessToast.show(context, "Copied to Clipboard");
                },
              ),
            if (!widget.message.isDeletedForEveryone)
              ListWhiteTiles(
                leading: const Icon(Icons.reply_rounded, color: Colors.black87),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onReplyPressed(widget.message);
                },
              ),

            // 🔴 ১০ মিনিটের মধ্যে পাঠালে এখানে 'Edit' অপশনটি দেখাবে 🔴
            if (_canEditMessage())
              ListWhiteTiles(
                leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                title: const Text('Edit', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context);
                },
              ),

            ListWhiteTiles(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete for Me', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _chatService.deleteMessageForMe(widget.chatRoomId, widget.message.messageId, widget.currentUserId);
              },
            ),
            if (widget.isMe && !widget.message.isDeletedForEveryone)
              ListWhiteTiles(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                title: const Text('Delete for Everyone', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(context);
                  await _chatService.deleteMessageForEveryone(widget.chatRoomId, widget.message.messageId);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.deletedForUsers.contains(widget.currentUserId)) {
      return const SizedBox.shrink();
    }

    final bubbleColor = widget.isMe ? const Color(0xFFE3F2FD) : Colors.white; 
    final msgType = widget.message.type.toLowerCase();

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showLongPressMenu(context), 
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
              bottomRight: Radius.circular(widget.isMe ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04), 
                blurRadius: 4, 
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.message.isDeletedForEveryone)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      "This message was deleted", 
                      style: TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ],
                )
              else ...[
                if (widget.message.replyToMessageId != null)
                  Container(
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(left: BorderSide(color: Color(0xFF1E4C7A), width: 3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.reply, size: 12, color: Color(0xFF1E4C7A)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            "Replied to a message",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (msgType == 'audio' || msgType == 'voice')
                  _buildAudioBubble()
                else if (msgType == 'image')
                  _buildImageBubble()
                else if (msgType == 'document' || msgType == 'file')
                  _buildDocumentBubble()
                else if (msgType == 'location')
                  _buildLocationBubble()
                else
                  Text(
                    widget.message.content, 
                    style: const TextStyle(fontSize: 14.5, color: Colors.black87, height: 1.3),
                  ),
              ],

              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(widget.message.timestamp),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 4),
                  if (widget.isMe) _buildStatusIcon(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ListWhiteTiles extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final VoidCallback onTap;

  const ListWhiteTiles({super.key, required this.leading, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading, 
      title: title, 
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}