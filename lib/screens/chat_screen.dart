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
  String _backgroundImageUrl = "assets/chat_bg.png"; // ডিফল্ট ব্যাকগ্রাউন্ড

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
  }

  // --- মেসেজ অ্যাকশন মেনু (Long Press) ---
  void _showContextMenu(BuildContext context, Offset offset, String messageId, String currentText, bool isMe) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx, offset.dy),
      items: [
        if (isMe) const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')])),
        const PopupMenuItem(value: 'delete_me', child: Row(children: [Icon(Icons.delete_outline), SizedBox(width: 8), Text('Delete for me')])),
        if (isMe) const PopupMenuItem(value: 'delete_all', child: Row(children: [Icon(Icons.delete_forever), SizedBox(width: 8), Text('Delete for everyone')])),
      ],
    ).then((value) {
      if (value == 'edit') _showEditDialog(context, messageId, currentText);
      if (value == 'delete_me' || value == 'delete_all') _deleteMessage(messageId, value == 'delete_all');
    });
  }

  // --- মেসেজ ডিলিট লজিক ---
  Future<void> _deleteMessage(String messageId, bool forEveryone) async {
    if (forEveryone) {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').doc(messageId).delete();
    } else {
      // Local delete logic can be added here
    }
  }

  // --- চ্যাট ব্যাকগ্রাউন্ড পরিবর্তন ---
  void _changeBackground() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _backgroundImageUrl = image.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 70,
        titleSpacing: 0,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: Row(
            children: [
              const Icon(Icons.arrow_back),
              CircleAvatar(backgroundColor: Colors.grey[300], child: const Icon(Icons.person, color: Colors.white)),
            ],
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.teacherName, style: const TextStyle(fontSize: 16)),
            const Text("Online", style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          PopupMenuButton(
            onSelected: (val) {
              if (val == 'bg') _changeBackground();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'bg', child: Text("Change Wallpaper")),
              const PopupMenuItem(value: 'clear', child: Text("Clear Chat")),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: _backgroundImageUrl.contains('assets') 
                ? AssetImage(_backgroundImageUrl) as ImageProvider 
                : FileImage(File(_backgroundImageUrl)),
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
                      return GestureDetector(
                        onLongPressStart: (details) => _showContextMenu(
                          context, details.globalPosition, doc.id, doc['message'] ?? "", isMe
                        ),
                        child: MessageBubble(
                          message: doc['message'] ?? '',
                          isMe: isMe,
                          timestamp: doc['timestamp'],
                          type: doc['type'],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(),
            if (_isEmojiVisible) SizedBox(height: 250, child: EmojiPicker(
              onEmojiSelected: (cat, emoji) => _messageController.text += emoji.emoji,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                    onPressed: () => setState(() => _isEmojiVisible = !_isEmojiVisible),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(hintText: "Message", border: InputBorder.none),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.camera_alt, color: Colors.grey), onPressed: () {}),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),
          CircleAvatar(
            backgroundColor: const Color(0xFF128C7E),
            child: IconButton(
              icon: Icon(_messageController.text.isEmpty ? Icons.mic : Icons.send, color: Colors.white),
              onPressed: () {
                if (_messageController.text.isNotEmpty) {
                  _sendMessage(_messageController.text);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
      'message': text,
      'senderId': widget.currentUserId,
      'timestamp': Timestamp.now(),
      'type': 'text',
    });
    _messageController.clear();
  }
}
