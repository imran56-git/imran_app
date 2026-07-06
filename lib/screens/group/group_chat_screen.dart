import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/message_bubble.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupName;
  final String groupId;
  final String currentUserId;
  final String currentUserName;

  const GroupChatScreen({
    super.key,
    required this.groupName,
    required this.groupId,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final ImagePicker _picker = ImagePicker();

  bool _isRecording = false;
  String? _recordedFilePath;
  String _backgroundImage = 'assets/default_bg.png';

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;

    if (!_recorder.isStopped && !_recorder.isRecording) return;

    await _recorder.openRecorder();
  }

  Future<void> _changeWallpaper() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _backgroundImage = image.path;
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      if (_isRecording) return;

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/${const Uuid().v4()}.aac';

      await _recorder.startRecorder(toFile: path);

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordedFilePath = path;
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  Future<void> _stopAndSendVoice() async {
    try {
      if (!_isRecording) return;

      final recordedPath = await _recorder.stopRecorder();

      if (!mounted) return;
      setState(() {
        _isRecording = false;
      });

      final path = recordedPath ?? _recordedFilePath;
      if (path == null) return;

      final file = File(path);
      if (!await file.exists()) return;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';
      final ref = FirebaseStorage.instance
          .ref()
          .child('group_voice')
          .child(widget.groupId)
          .child(fileName);

      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: 'audio/aac'),
      );

      final url = await uploadTask.ref.getDownloadURL();

      await _sendToFirestore(content: url, type: 'audio');

      if (await file.exists()) {
        await file.delete();
      }

      _recordedFilePath = null;
    } catch (e) {
      debugPrint('Stop/send voice error: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await _sendToFirestore(content: text, type: 'text');
    _messageController.clear();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sendToFirestore({
    required String content,
    required String type,
  }) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .add({
      'senderId': widget.currentUserId,
      'senderName': widget.currentUserName,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      'isSeen': false,
    });
  }

  Future<void> _deleteMessageForEveryone(String messageId) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> _showEditDialog(String messageId, String oldText) async {
    final controller = TextEditingController(text: oldText);

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Update your message',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .doc(messageId)
          .update({
        'content': result,
        'edited': true,
      });
    }
  }

  Future<void> _showOptions({
    required String messageId,
    required String text,
    required bool isMe,
    required String type,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (isMe && type == 'text')
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Message'),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete for me'),
                onTap: () => Navigator.pop(context, 'delete_me'),
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined),
                  title: const Text('Delete for everyone'),
                  onTap: () => Navigator.pop(context, 'delete_all'),
                ),
            ],
          ),
        );
      },
    );

    if (selected == 'edit') {
      await _showEditDialog(messageId, text);
    } else if (selected == 'delete_all') {
      await _deleteMessageForEveryone(messageId);
    } else if (selected == 'delete_me') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delete for me is not connected yet.'),
          ),
        );
      }
    }
  }

  Widget _buildInputArea() {
    final hasText = _messageController.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.emoji_emotions_outlined,
                        color: Colors.grey,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.attach_file,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onLongPressStart: hasText ? null : (_) => _startRecording(),
              onLongPressEnd: hasText ? null : (_) => _stopAndSendVoice(),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF128C7E),
                child: IconButton(
                  onPressed: hasText ? _sendTextMessage : null,
                  icon: Icon(
                    hasText
                        ? Icons.send
                        : (_isRecording ? Icons.stop : Icons.mic),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider backgroundProvider =
        _backgroundImage.startsWith('assets/')
            ? AssetImage(_backgroundImage)
            : FileImage(File(_backgroundImage));

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              child: Icon(Icons.group, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Group chat',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'wallpaper') {
                _changeWallpaper();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'wallpaper',
                child: Text('Change Wallpaper'),
              ),
              PopupMenuItem<String>(
                value: 'info',
                child: Text('Group Info'),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: backgroundProvider,
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Failed to load messages'),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final String message = (data['content'] ?? '').toString();
                      final String type = (data['type'] ?? 'text').toString();
                      final bool isMe =
                          data['senderId'] == widget.currentUserId;

                      return GestureDetector(
                        onLongPress: () => _showOptions(
                          messageId: doc.id,
                          text: message,
                          isMe: isMe,
                          type: type,
                        ),
                        child: MessageBubble(
                          message: message,
                          isMe: isMe,
                          timestamp: data['timestamp'] as Timestamp?,
                          messageId: doc.id,
                          type: type == 'voice' ? 'audio' : type,
                          isTyping: false,
                          uploadVoiceMessage: () {},
                          isSeen: data['isSeen'] ?? false,
                          isDelivered: true,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }
}