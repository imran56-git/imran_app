import 'dart:async'; import 'dart:io'; import 'package:flutter/material.dart'; import 'package:image_picker/image_picker.dart'; import 'package:flutter_sound/flutter_sound.dart'; import 'package:emoji_picker_flutter/emoji_picker_flutter.dart'; import 'package:permission_handler/permission_handler.dart'; import 'package:path_provider/path_provider.dart'; import 'package:cloud_firestore/cloud_firestore.dart'; import 'package:just_audio/just_audio.dart'; import '../services/voice_message_handler.dart'; import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget { final String teacherName; final String chatId; final String currentUserId; final String receiverId;

const ChatScreen({ super.key, required this.teacherName, required this.chatId, required this.currentUserId, required this.receiverId, });

@override State<ChatScreen> createState() => _ChatScreenState(); }

class _ChatScreenState extends State<ChatScreen> { final TextEditingController _messageController = TextEditingController(); final FlutterSoundRecorder _recorder = FlutterSoundRecorder(); final AudioPlayer _audioPlayer = AudioPlayer(); final ImagePicker _picker = ImagePicker(); final VoiceMessageHandler _voiceHandler = VoiceMessageHandler();

bool _isRecording = false; bool _isEmojiVisible = false; bool _isTyping = false; bool _isTeacherOnline = true; DateTime _lastSeen = DateTime.now().subtract(const Duration(minutes: 30));

Timer? _typingTimer;

@override void initState() { super.initState(); _initRecorder(); _autoSendInviteMessage(); }

Future<void> _initRecorder() async { await Permission.microphone.request(); await _recorder.openRecorder(); }

void _autoSendInviteMessage() async { await _sendMessage( "Hello teacher, I’ve seen your profile and I’m really interested in learning from you. I need proper guidance and would love to start a great learning journey with your help." ); }

Future<void> _sendMessage(String text) async { if (text.trim().isEmpty) return;

final isUserBlocked = await isBlocked(widget.currentUserId, widget.receiverId);
if (isUserBlocked) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('You are blocked by this user.')),
  );
  return;
}

await FirebaseFirestore.instance.collection('chats')
  .doc(widget.chatId).collection('messages').add({
    'message': text,
    'senderId': widget.currentUserId,
    'receiverId': widget.receiverId,
    'timestamp': Timestamp.now(),
    'type': 'text',
  });

_messageController.clear();

}

Future<void> _pickImage() async { final pickedFile = await _picker.pickImage(source: ImageSource.gallery); if (pickedFile != null) { final imageFile = File(pickedFile.path); // Upload logic needed here } }

Future<void> _startOrStopRecording() async { if (_isRecording) { final audioUrl = await _voiceHandler.stopAndUploadRecording(widget.chatId); if (audioUrl != null) { await FirebaseFirestore.instance.collection('chats') .doc(widget.chatId).collection('messages').add({ 'senderId': widget.currentUserId, 'receiverId': widget.receiverId, 'audioUrl': audioUrl, 'timestamp': Timestamp.now(), 'type': 'audio', }); } } else { await _voiceHandler.startRecording(); } setState(() => _isRecording = !_isRecording); }

Future<void> deleteMessage(String messageId) async { await FirebaseFirestore.instance .collection('chats') .doc(widget.chatId) .collection('messages') .doc(messageId) .delete(); }

Future<void> blockUser(String blockerId, String blockedId) async { final blockDocId = '${blockerId}_$blockedId'; await FirebaseFirestore.instance.collection('blocks').doc(blockDocId).set({ 'blockerId': blockerId, 'blockedId': blockedId, 'timestamp': FieldValue.serverTimestamp(), }); }

Future<void> unblockUser(String blockerId, String blockedId) async { final blockDocId = '${blockerId}_$blockedId'; await FirebaseFirestore.instance.collection('blocks').doc(blockDocId).delete(); }

Future<bool> isBlocked(String senderId, String receiverId) async { final blockDocId = '${receiverId}_$senderId'; final doc = await FirebaseFirestore.instance.collection('blocks').doc(blockDocId).get(); return doc.exists; }

void _onTyping(String value) { if (!_isTyping) setState(() => _isTyping = true); _typingTimer?.cancel(); _typingTimer = Timer(const Duration(seconds: 2), () { setState(() => _isTyping = false); }); }

String _getStatusText() { if (_isTeacherOnline) { return _isTyping ? 'Typing...' : 'Online'; } else { final duration = DateTime.now().difference(_lastSeen); if (duration.inMinutes < 60) return 'Last seen ${duration.inMinutes} minutes ago'; if (duration.inHours < 24) return 'Last seen ${duration.inHours} hours ago'; return 'Last seen on ${_lastSeen.day}/${_lastSeen.month}/${_lastSeen.year}'; } }

void _showEditDialog(BuildContext context, String messageId, String oldMessage) { TextEditingController _editController = TextEditingController(text: oldMessage); showDialog( context: context, builder: (context) => AlertDialog( title: const Text('Edit Message'), content: TextField(controller: _editController), actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), TextButton( onPressed: () { FirebaseFirestore.instance.collection('chats') .doc(widget.chatId).collection('messages') .doc(messageId).update({'message': _editController.text}); Navigator.pop(context); }, child: const Text('Save'), ), ], ), ); }

@override void dispose() { _recorder.closeRecorder(); _typingTimer?.cancel(); super.dispose(); }

@override Widget build(BuildContext context) { return Scaffold( appBar: AppBar( title: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(widget.teacherName), Text(_getStatusText(), style: const TextStyle(fontSize: 12)), ], ), actions: [ IconButton( icon: const Icon(Icons.block), onPressed: () => blockUser(widget.currentUserId, widget.receiverId), ), IconButton( icon: const Icon(Icons.lock_open), onPressed: () => unblockUser(widget.currentUserId, widget.receiverId), ), ], ), body: Column( children: [ Expanded( child: StreamBuilder<QuerySnapshot>( stream: FirebaseFirestore.instance .collection('chats') .doc(widget.chatId) .collection('messages') .orderBy('timestamp', descending: true) .snapshots(), builder: (context, snapshot) { if (!snapshot.hasData) { return const Center(child: CircularProgressIndicator()); } return ListView( reverse: true, children: snapshot.data!.docs.map((message) { final data = message.data() as Map<String, dynamic>; return MessageBubble( message: data['message'] ?? '', isMe: data['senderId'] == widget.currentUserId, messageId: message.id, currentUserId: widget.currentUserId, onEdit: _showEditDialog, timestamp: data['timestamp'], ); }).toList(), ); }, ), ), if (_isEmojiVisible) SizedBox( height: 250, child: EmojiPicker( onEmojiSelected: (category, emoji) => _messageController.text += emoji.emoji, config: const Config(columns: 7, emojiSizeMax: 28), ), ), Container( padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), color: Colors.grey[100], child: Row( children: [ IconButton( icon: const Icon(Icons.emoji_emotions_outlined), onPressed: () => setState(() => _isEmojiVisible = !_isEmojiVisible), ), IconButton(icon: const Icon(Icons.image), onPressed: _pickImage), IconButton( icon: Icon(_isRecording ? Icons.stop : Icons.mic), onPressed: _startOrStopRecording, ), Expanded( child: TextField( controller: _messageController, onChanged: _onTyping, decoration: const InputDecoration(hintText: 'Type a message', border: InputBorder.none), ), ), IconButton(

