import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
class GroupChatScreen extends StatefulWidget {
  final String groupName;
  const GroupChatScreen({super.key, required this.groupName});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> messages = [];

final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
bool _isRecording = false;
String? _recordedFilePath;

Future<void> _initRecorder() async {
  await Permission.microphone.request();
  await _recorder.openRecorder();
}

Future<void> _startRecording() async {
  final tempDir = await getTemporaryDirectory();
  final filePath = '${tempDir.path}/${const Uuid().v4()}.aac';
  await _recorder.startRecorder(toFile: filePath);
  setState(() {
    _isRecording = true;
    _recordedFilePath = filePath;
  });
}

Future<void> _stopRecordingAndSend() async {
  await _recorder.stopRecorder();
  setState(() {
    _isRecording = false;
  });

  if (_recordedFilePath != null) {
    try {
      final File voiceFile = File(_recordedFilePath!);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';

      // Firebase Storage path
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('group_voice_messages')
          .child(widget.groupId)
          .child(fileName);

      // Upload to Firebase Storage
      final uploadTask = await storageRef.putFile(voiceFile);

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Save message in Firestore
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add({
        'senderId': widget.currentUserId,
        'voiceUrl': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'voice',
      });

      setState(() {
        _recordedFilePath = null;
      });
    } catch (e) {
      print('ভয়েস মেসেজ পাঠাতে সমস্যা হয়েছে: $e');
    }
  }
}

void _sendMessage() {
  final messageText = _messageController.text.trim();
  if (messageText.isNotEmpty) {
    FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .add({
      'senderId': widget.currentUserId,
      'text': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    });
    _messageController.clear();
  }
}

@override
void initState() {
  super.initState();
  _initRecorder();
}

  void sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      setState(() {
        messages.add(message);
        _messageController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(messages[index]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
const SizedBox(width: 4), 
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
GestureDetector(
  onLongPress: _startRecording,
  onLongPressUp: _stopRecordingAndSend,
  child: Icon(
    _isRecording ? Icons.stop : Icons.mic,
    color: _isRecording ? Colors.red : Colors.black,
  ),
),

              ],
            ),
          ),
        ],
      ),
    );
  }
}