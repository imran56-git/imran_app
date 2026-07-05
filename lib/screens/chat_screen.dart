import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final ImagePicker _picker = ImagePicker();
  final VoiceMessageHandler _voiceHandler = VoiceMessageHandler();

  bool _isRecording = false;
  bool _isEmojiVisible = false;
  bool _isTyping = false;
  String _backgroundImageUrl = "assets/chat_bg.png";

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _isTyping = _messageController.text.trim().isNotEmpty;
    });
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status == PermissionStatus.granted) {
      await _recorder.openRecorder();
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'message': text,
      'senderId': widget.currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    });
    _messageController.clear();
    setState(() => _isTyping = false);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      String? path = await _recorder.stopRecorder();
      setState(() => _isRecording = false);
      if (path != null) {
        String? remoteUrl = await _voiceHandler.stopAndUploadRecording(widget.chatId);
        if (remoteUrl != null) {
          await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
            'message': remoteUrl,
            'senderId': widget.currentUserId,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'audio',
          });
        }
      }
    } else {
      await _recorder.startRecorder(toFile: 'audio_msg.aac');
      setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/app_logo.png', height: 40, width: 40, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Text(widget.teacherName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: _backgroundImageUrl.contains('assets') ? AssetImage(_backgroundImageUrl) as ImageProvider : FileImage(File(_backgroundImageUrl)),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  return ListView.builder(
                    reverse: true,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      bool isMe = doc['senderId'] == widget.currentUserId;
                      return MessageBubble(
                        message: doc['message'] ?? '',
                        isMe: isMe,
                        timestamp: doc['timestamp'],
                        type: doc['type'],
                        messageId: doc.id,
                        isTyping: false,
                        uploadVoiceMessage: () {},
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(),
            if (_isEmojiVisible)
              SizedBox(
                height: 250,
                child: EmojiPicker(onEmojiSelected: (cat, emoji) => setState(() => _messageController.text += emoji.emoji)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(25)),
              child: Row(
                children: [
                  IconButton(icon: Icon(_isEmojiVisible ? Icons.keyboard : Icons.emoji_emotions_outlined), onPressed: () => setState(() => _isEmojiVisible = !_isEmojiVisible)),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF1A237E),
            child: IconButton(
              icon: Icon(_isTyping ? Icons.send : (_isRecording ? Icons.stop : Icons.mic), color: Colors.white),
              onPressed: () => _isTyping ? _sendMessage(_messageController.text.trim()) : _toggleRecording(),
            ),
          ),
        ],
      ),
    );
  }
}
