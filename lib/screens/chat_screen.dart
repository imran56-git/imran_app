import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/teacher_model.dart'; // Future use if needed
import '../services/chat_service.dart'; // Future use if needed
import 'package:your_app/services/voice_message_handler.dart';
import 'package:just_audio/just_audio.dart';

class ChatScreen extends StatefulWidget {
  final String teacherName;

  const ChatScreen({super.key, required this.teacherName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

VoiceMessageHandler _voiceHandler = VoiceMessageHandler();
bool _isRecording = false;
final AudioPlayer _audioPlayer = AudioPlayer();

  final TextEditingController _messageController = TextEditingController();
  void _showEditDialog(BuildContext context, String messageId, String oldMessage) {
  TextEditingController _editController = TextEditingController(text: oldMessage);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Message'),
      content: TextField(
        controller: _editController,
        decoration: const InputDecoration(hintText: "Enter new message"),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: const Text('Save'),
          onPressed: () {
            FirebaseFirestore.instance
                .collection('messages')
                .doc(messageId)
                .update({'message': _editController.text});
            Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}

  final List<Widget> messages = [];
  final ImagePicker _picker = ImagePicker();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isEmojiVisible = false;
  bool _isTyping = false;
  bool _isTeacherOnline = true;
  DateTime _lastSeen = DateTime.now().subtract(const Duration(minutes: 30));

  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _autoSendInviteMessage(); // Auto-send message on screen open
  }

  void _autoSendInviteMessage() {
    Future.delayed(Duration.zero, () {
      _sendMessage(
        "Hello teacher, I’ve seen your profile and I’m really interested in learning from you. "
        "I need proper guidance and would love to start a great learning journey with your help.",
      );
    });
  }

  Future<void> _initRecorder() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
  }

  void _sendMessage(String text) async {
  if (text.trim().isEmpty) return;
  // rest of the logic
}

  final isUserBlocked = await isBlocked(currentUserId, widget.receiverId);
  if (isUserBlocked) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You are blocked by this user.')),
    );
    return;
  }

  // Proceed to send message
  FirebaseFirestore.instance.collection('messages').add({
    'message': text,
    'senderId': currentUserId,
    'receiverId': widget.receiverId,
    'timestamp': Timestamp.now(),
  });

  _messageController.clear();
}

void deleteMessage(String messageId) async {
  await FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .doc(messageId)
      .delete();
}

Future<void> blockUser(String blockerId, String blockedId) async {
  final blockDocId = '${blockerId}_$blockedId';
  await FirebaseFirestore.instance.collection('blocks').doc(blockDocId).set({
    'blockerId': blockerId,
    'blockedId': blockedId,
    'timestamp': FieldValue.serverTimestamp(),
  });
}

Future<void> unblockUser(String blockerId, String blockedId) async {
  final blockDocId = '${blockerId}_$blockedId';
  await FirebaseFirestore.instance.collection('blocks').doc(blockDocId).delete();
}

Future<bool> isBlocked(String senderId, String receiverId) async {
  final blockDocId = '${receiverId}_$senderId'; // Receiver blocked sender?
  final doc = await FirebaseFirestore.instance.collection('blocks').doc(blockDocId).get();
  return doc.exists;
}

  Widget _buildTextMessage(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _buildImageMessage(File file) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFD0E8F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Image.file(file, width: 150),
      ),
    );
  }
return GestureDetector(
  onLongPress: () {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Message?'),
        actions: [
          TextButton(
            onPressed: () {
              deleteMessage(message.id);
              Navigator.pop(context);
            },
            child: Text('DELETE'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
        ],
      ),
    );
  },
  
  child: Container(
    padding: EdgeInsets.all(10),
    margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(message['text']),
  ),
);

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);
      setState(() {
        messages.add(_buildImageMessage(imageFile));
      });
    }
  }

  Future<void> _startOrStopRecording() async {
    if (!_isRecording) {
      final dir = await getApplicationDocumentsDirectory();
      String path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder.startRecorder(toFile: path);
    } else {
      final path = await _recorder.stopRecorder();
      if (path != null) {
        setState(() {
          messages.add(_buildAudioMessage(File(path)));
        });
      }
    }
    setState(() {
      _isRecording = !_isRecording;
    });
  }

  Widget _buildAudioMessage(File audioFile) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFD7CCC8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.play_arrow),
            SizedBox(width: 8),
            Text('Voice message'),
          ],
        ),
      ),
    );
  }

ElevatedButton(
  onPressed: () {
    blockUser(currentUserId, widget.receiverId);
  },
  child: Text('Block'),
),
  void _onTyping(String value) {
    if (!_isTyping) {
      setState(() => _isTyping = true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      setState(() => _isTyping = false);
    });
  }

ElevatedButton(
  onPressed: () {
    unblockUser(currentUserId, widget.receiverId);
  },
  child: Text('Unblock'),
),

  String _getStatusText() {
    if (_isTeacherOnline) {
      return _isTyping ? 'Typing...' : 'Online';
    } else {
      final duration = DateTime.now().difference(_lastSeen);
      if (duration.inMinutes < 60) {
        return 'Last seen ${duration.inMinutes} minutes ago';
      } else if (duration.inHours < 24) {
        return 'Last seen ${duration.inHours} hours ago';
      } else {
        return 'Last seen on ${_lastSeen.day}/${_lastSeen.month}/${_lastSeen.year}';
      }
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.teacherName),
            Text(
              _getStatusText(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      Expanded(
  child: StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Center(child: CircularProgressIndicator());
      }

      final messages = snapshot.data!.docs;

      return ListView.builder(
        reverse: true,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final data = message.data() as Map<String, dynamic>;

          if (data['type'] == 'text') {
            return Align(
              alignment: data['senderId'] == currentUserId
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: data['senderId'] == currentUserId
                      ? Colors.green.shade100
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(data['text'] ?? ''),
              ),
            );
          }

          if (data['type'] == 'audio') {
            return Align(
              alignment: data['senderId'] == currentUserId
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.play_arrow),
                      onPressed: () async {
                        await _audioPlayer.setUrl(data['audioUrl']);
                        _audioPlayer.play();
                      },
                    ),
                    const Text("Voice Message"),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink(); // fallback
        },
      );
    },
  ),
),

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: snapshot.data!.docs.map((message) {
              final messageId = message.id;
              final data = message.data() as Map<String, dynamic>;
              return MessageBubble(
                message: data['message'],
                isMe: data['senderId'] == currentUserId,
                timestamp: data['timestamp'],
              );
            }).toList(),
          ),
        ),
        if (_isEmojiVisible)
          SizedBox(
            height: 250,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                _messageController.text += emoji.emoji;
              },
              config: const Config(columns: 7, emojiSizeMax: 28),
            ),
          ),
      ],
    );
  },
),
              children: snapshot.data!.docs.map((message) {
  final messageId = message.id;
  final data = message.data() as Map<String, dynamic>;
  return MessageBubble(
    message: data['message'],
    isMe: data['senderId'] == currentUserId,
    timestamp: data['timestamp'],
  );
  
}).toList(),
          if (_isEmojiVisible)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _messageController.text += emoji.emoji;
                },
                config: const Config(columns: 7, emojiSizeMax: 28),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.grey[100],
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  onPressed: () {
                    setState(() {
                      _isEmojiVisible = !_isEmojiVisible;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _pickImage,
                ),
                IconButton(
  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
  onPressed: () async {
    if (_isRecording) {
      setState(() => _isRecording = false);
      final audioUrl = await _voiceHandler.stopAndUploadRecording(widget.chatId);
      if (audioUrl != null) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .add({
          'senderId': currentUserId,
          'receiverId': receiverUserId,
          'audioUrl': audioUrl,
          'timestamp': Timestamp.now(),
          'type': 'audio',
        });
      }
    } else {
      await _voiceHandler.startRecording();
      setState(() => _isRecording = true);
    }
  },
),

                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: _onTyping,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(_messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}