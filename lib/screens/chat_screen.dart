import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/voice_message_handler.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String teacherName;
  final String chatId;
  final String currentUserId;
  final String receiverId;

  const ChatScreen({
    super.key,
    required this.teacherName,
    required this.chatId,
    required this.currentUserId,
    required this.receiverId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final VoiceMessageHandler _voiceHandler = VoiceMessageHandler();

  bool _isEmojiVisible = false, _isTyping = false, _isRecording = false, _isBlocked = false;
  String _backgroundImageUrl = 'assets/images/chat_bg.png';
  String? _senderImageUrl, _receiverImageUrl, _receiverName;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      final typing = _messageController.text.trim().isNotEmpty;
      if (_isTyping != typing) setState(() => _isTyping = typing);
    });
    _initVoiceRecorder();
    _markMessagesAsSeen();
    _loadUserImages();
    _loadBlockedStatus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _voiceHandler.dispose();
    super.dispose();
  }

  Future<void> _initVoiceRecorder() async {
    try { await _voiceHandler.initRecorder(); } catch (_) {}
  }

  Future<void> _loadUserImages() async {
    try {
      final db = FirebaseFirestore.instance;
      final senderDoc = await db.collection('users').doc(widget.currentUserId).get();
      final receiverDoc = await db.collection('users').doc(widget.receiverId).get();
      if (!mounted) return;
      setState(() {
        _senderImageUrl = senderDoc.data()?['profileImageUrl'] ?? '';
        _receiverImageUrl = receiverDoc.data()?['profileImageUrl'] ?? '';
        _receiverName = receiverDoc.data()?['teacherName'] ?? widget.teacherName;
      });
    } catch (_) {}
  }

  Future<void> _loadBlockedStatus() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
      if (doc.exists && mounted) {
        final blockedBy = doc.data()?['blockedBy'] as List<dynamic>?;
        setState(() => _isBlocked = blockedBy?.contains(widget.currentUserId) ?? false);
      }
    } catch (_) {}
  }

  Future<void> _sendMessage(String text, String type) async {
    if ((type == 'text' && text.trim().isEmpty) || _isBlocked) return;
    final messageText = text.trim();
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    batch.set(db.collection('chats').doc(widget.chatId).collection('messages').doc(), {
      'message': messageText,
      'senderId': widget.currentUserId,
      'receiverId': widget.receiverId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      'isSeen': false,
    });

    batch.update(db.collection('chats').doc(widget.chatId), {
      'lastMessage': messageText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': FieldValue.increment(1),
    });

    await batch.commit();
    if (type == 'text') {
      _messageController.clear();
      if (mounted) setState(() => _isTyping = false);
    }
  }

  Future<void> _checkAndCreateChat() async {
    final ref = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'chatId': widget.chatId,
        'teacherId': widget.currentUserId,
        'studentId': widget.receiverId,
        'teacherName': _receiverName ?? widget.teacherName,
        'studentName': 'Student',
        'teacherImage': _senderImageUrl,
        'studentImage': _receiverImageUrl,
        'participants': [widget.currentUserId, widget.receiverId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': 0,
        'blockedBy': [],
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isBlocked) return;
    try {
      if (_isRecording) {
        final audioUrl = await _voiceHandler.stopAndUploadRecording(widget.chatId);
        if (mounted) setState(() => _isRecording = false);
        if (audioUrl != null && audioUrl.isNotEmpty) await _sendMessage(audioUrl, 'audio');
      } else {
        await _voiceHandler.startRecording();
        if (mounted) setState(() => _isRecording = true);
      }
    } catch (_) {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _markMessagesAsSeen() async {
    try {
      final db = FirebaseFirestore.instance;
      final query = await db.collection('chats').doc(widget.chatId).collection('messages')
          .where('receiverId', isEqualTo: widget.currentUserId).where('isSeen', isEqualTo: false).get();
      final batch = db.batch();
      for (var doc in query.docs) { batch.update(doc.reference, {'isSeen': true}); }
      batch.update(db.collection('chats').doc(widget.chatId), {'unreadCount': 0});
      await batch.commit();
    } catch (_) {}
  }

  Future<void> _clearChat() async {
    try {
      final db = FirebaseFirestore.instance;
      final snapshot = await db.collection('chats').doc(widget.chatId).collection('messages').get();
      final batch = db.batch();
      for (var doc in snapshot.docs) { batch.delete(doc.reference); }
      await batch.commit();
    } catch (_) {}
  }

  void _showActionDialog(String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () { Navigator.pop(context); onConfirm(); }, child: Text(title.split(' ')[0])),
        ],
      ),
    );
  }

  Future<void> _handleBlock() async {
    try {
      final update = _isBlocked ? FieldValue.arrayRemove([widget.currentUserId]) : FieldValue.arrayUnion([widget.currentUserId]);
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({'blockedBy': update});
      setState(() => _isBlocked = !_isBlocked);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              backgroundImage: (_receiverImageUrl != null && _receiverImageUrl!.isNotEmpty) ? NetworkImage(_receiverImageUrl!) : null,
              child: (_receiverImageUrl == null || _receiverImageUrl!.isEmpty) ? const Icon(Icons.person, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(_receiverName ?? widget.teacherName, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600))),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.call, color: Colors.white)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.videocam, color: Colors.white)),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'clear') _showActionDialog('Clear Chat', 'Delete all messages?', _clearChat);
              if (val == 'block') _showActionDialog(_isBlocked ? 'Unblock Teacher' : 'Block Teacher', _isBlocked ? 'Unblock this teacher?' : 'Block this teacher?', _handleBlock);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'clear', child: Text('Clear Chat')),
              PopupMenuItem(value: 'block', child: Text(_isBlocked ? 'Unblock Teacher' : 'Block Teacher')),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(image: DecorationImage(image: _backgroundImageUrl.startsWith('assets/') ? AssetImage(_backgroundImageUrl) : FileImage(File(_backgroundImageUrl)) as ImageProvider, fit: BoxFit.cover)),
        child: Column(
          children: [
            if (_isBlocked) Container(width: double.infinity, padding: const EdgeInsets.all(10), color: Colors.red.shade50, child: const Text('You blocked this teacher.', textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600))),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No messages yet', style: TextStyle(color: Colors.black54, fontSize: 15)));
                  return ListView.builder(
                    controller: _scrollController, reverse: true, itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      return MessageBubble(
                        message: data['message'].toString(), isMe: data['senderId'] == widget.currentUserId,
                        timestamp: data['timestamp'] as Timestamp?, type: data['type'].toString(),
                        messageId: snapshot.data!.docs[index].id, isTyping: false, uploadVoiceMessage: () {}, isSeen: data['isSeen'] ?? false, isDelivered: true,
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                        child: Row(children: [
                          IconButton(onPressed: () => setState(() => _isEmojiVisible = !_isEmojiVisible), icon: Icon(_isEmojiVisible ? Icons.keyboard : Icons.emoji_emotions_outlined)),
                          Expanded(child: TextField(controller: _messageController, minLines: 1, maxLines: 5, decoration: const InputDecoration(hintText: 'Type a message', border: InputBorder.none))),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 24, backgroundColor: const Color(0xFF128C7E),
                      child: IconButton(
                        onPressed: _isBlocked ? null : () { if (_isTyping) { _checkAndCreateChat().then((_) => _sendMessage(_messageController.text, 'text')); } else { _toggleRecording(); } },
                        icon: Icon(_isTyping ? Icons.send : (_isRecording ? Icons.stop : Icons.mic), color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isEmojiVisible) SizedBox(height: 260, child: EmojiPicker(onEmojiSelected: (cat, em) => _messageController.text += em.emoji)),
          ],
        ),
      ),
    );
  }
}
