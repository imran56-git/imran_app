import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/voice_message_handler.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String teacherName;
  final String chatId;
  final String currentUserId;
  final String receiverId;
  final String? teacherImage;
  final String? teacherSubtitle;

  const ChatScreen({
    super.key,
    required this.teacherName,
    required this.chatId,
    required this.currentUserId,
    required this.receiverId,
    this.teacherImage,
    this.teacherSubtitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final ImagePicker _picker = ImagePicker();
  final VoiceMessageHandler _voiceHandler = VoiceMessageHandler();

  bool _isRecording = false;
  bool _isEmojiVisible = false;
  bool _isTyping = false;
  bool _isUploadingMedia = false;

  /// Default wallpaper
  /// চাইলে এখানে তোমার custom wallpaper asset বসাতে পারো
  String _backgroundImageUrl = "assets/chat_bg.png";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initRecorder();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    Future.delayed(const Duration(milliseconds: 200), _scrollToBottom);
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (_isTyping != hasText) {
      setState(() => _isTyping = hasText);
    }
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status == PermissionStatus.granted) {
      await _recorder.openRecorder();
    }
  }

  Future<void> _updateChatMeta({
    required String lastMessage,
    required String type,
  }) async {
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
      'chatId': widget.chatId,
      'participants': [widget.currentUserId, widget.receiverId],
      'lastMessage': lastMessage,
      'lastMessageType': type,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'teacherName': widget.teacherName,
      'teacherId': widget.receiverId,
      'studentId': widget.currentUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'message': trimmed,
      'senderId': widget.currentUserId,
      'receiverId': widget.receiverId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isRead': false,
      'isDeleted': false,
    });

    await _updateChatMeta(lastMessage: trimmed, type: 'text');

    _messageController.clear();
    setState(() => _isTyping = false);
    _scrollToBottom();
  }

  Future<void> _sendImageMessage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploadingMedia = true);

      /// এখানে আপাতত local path save করছি।
      /// যদি তোমার Firebase Storage upload already ready থাকে,
      /// তাহলে এখানে upload করে remote URL save করবে।
      final imagePath = image.path;

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'message': imagePath,
        'senderId': widget.currentUserId,
        'receiverId': widget.receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'image',
        'isRead': false,
        'isDeleted': false,
      });

      await _updateChatMeta(lastMessage: '📷 Photo', type: 'image');
    } catch (e) {
      _showSnack('Image send failed');
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
      _scrollToBottom();
    }
  }

  Future<void> _openCameraAndSend() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      setState(() => _isUploadingMedia = true);

      final imagePath = image.path;

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'message': imagePath,
        'senderId': widget.currentUserId,
        'receiverId': widget.receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'image',
        'isRead': false,
        'isDeleted': false,
      });

      await _updateChatMeta(lastMessage: '📷 Camera Photo', type: 'image');
    } catch (e) {
      _showSnack('Camera send failed');
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
      _scrollToBottom();
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        String? path = await _recorder.stopRecorder();
        setState(() => _isRecording = false);

        if (path != null) {
          /// তোমার VoiceMessageHandler already project-এ আছে,
          /// তাই সেটা ব্যবহার করছি
          String? remoteUrl =
              await _voiceHandler.stopAndUploadRecording(widget.chatId);

          final audioMessage = remoteUrl ?? path;

          await FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .collection('messages')
              .add({
            'message': audioMessage,
            'senderId': widget.currentUserId,
            'receiverId': widget.receiverId,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'audio',
            'isRead': false,
            'isDeleted': false,
          });

          await _updateChatMeta(lastMessage: '🎤 Voice message', type: 'audio');
          _scrollToBottom();
        }
      } else {
        final micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          _showSnack('Microphone permission denied');
          return;
        }

        await _recorder.startRecorder(toFile: 'audio_msg.aac');
        setState(() => _isRecording = true);
      }
    } catch (e) {
      _showSnack('Voice recording failed');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _clearChat() async {
    final confirm = await _showConfirmDialog(
      title: 'Clear chat',
      content: 'এই chat-এর সব message clear করতে চাও?',
      confirmText: 'Clear',
    );

    if (!confirm) return;

    try {
      final messages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }

      batch.set(
        FirebaseFirestore.instance.collection('chats').doc(widget.chatId),
        {
          'lastMessage': '',
          'lastMessageType': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      _showSnack('Chat cleared');
    } catch (e) {
      _showSnack('Failed to clear chat');
    }
  }

  Future<void> _blockUser() async {
    final confirm = await _showConfirmDialog(
      title: 'Block teacher',
      content: 'তুমি কি এই teacher-কে block করতে চাও?',
      confirmText: 'Block',
    );

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
        'blockedBy': widget.currentUserId,
        'isBlocked': true,
      }, SetOptions(merge: true));

      _showSnack('Teacher blocked');
    } catch (e) {
      _showSnack('Failed to block');
    }
  }

  Future<void> _simChangeAction() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('SIM Change'),
        content: const Text(
          'এই option-এর backend logic পরে connect করবে।\n\nএখন চাইলে এখানে SIM change request flow / support flow add করতে পারো।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF128C7E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDateHeader(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDate).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(date);
  }

  Widget _buildPopupMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.black87),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (value) async {
        switch (value) {
          case 'block':
            await _blockUser();
            break;
          case 'sim_change':
            await _simChangeAction();
            break;
          case 'clear_chat':
            await _clearChat();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'block',
          child: Text('Block'),
        ),
        PopupMenuItem(
          value: 'sim_change',
          child: Text('SIM Change'),
        ),
        PopupMenuItem(
          value: 'clear_chat',
          child: Text('Clear Chat'),
        ),
      ],
    );
  }

  Widget _buildChatHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE7F7F4),
              backgroundImage: widget.teacherImage != null &&
                      widget.teacherImage!.trim().isNotEmpty
                  ? NetworkImage(widget.teacherImage!)
                  : null,
              child: widget.teacherImage == null || widget.teacherImage!.isEmpty
                  ? Text(
                      widget.teacherName.isNotEmpty
                          ? widget.teacherName[0].toUpperCase()
                          : 'T',
                      style: const TextStyle(
                        color: Color(0xFF128C7E),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {},
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.teacherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.teacherSubtitle ?? 'Online',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildPopupMenu(),
          ],
        ),
      ),
    );
  }

  Widget _buildWallpaperWrapper({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: _backgroundImageUrl.contains('assets')
              ? AssetImage(_backgroundImageUrl) as ImageProvider
              : FileImage(File(_backgroundImageUrl)),
          fit: BoxFit.cover,
          opacity: 0.10,
        ),
        color: const Color(0xFFF7F8FA),
      ),
      child: child,
    );
  }

  Widget _buildMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF128C7E)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            final bool isMe = data['senderId'] == widget.currentUserId;
            final Timestamp? timestamp = data['timestamp'] as Timestamp?;
            final String type = (data['type'] ?? 'text').toString();
            final String message = (data['message'] ?? '').toString();

            bool showDateHeader = false;
            if (index == docs.length - 1) {
              showDateHeader = true;
            } else {
              final currentTs = docs[index]['timestamp'] as Timestamp?;
              final nextTs = docs[index + 1]['timestamp'] as Timestamp?;
              if (_formatDateHeader(currentTs) != _formatDateHeader(nextTs)) {
                showDateHeader = true;
              }
            }

            return Column(
              children: [
                if (showDateHeader)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        _formatDateHeader(timestamp),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                MessageBubble(
                  message: message,
                  isMe: isMe,
                  timestamp: timestamp,
                  type: type,
                  messageId: doc.id,
                  isTyping: false,
                  uploadVoiceMessage: () {},
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF128C7E).withOpacity(0.10),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 42,
                color: Color(0xFF128C7E),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Say hello to ${widget.teacherName} 👋',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAttachmentSheet() async {
    await showModa