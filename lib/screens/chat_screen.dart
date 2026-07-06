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

  bool _isEmojiVisible = false;
  bool _isTyping = false;
  bool _isRecording = false;
  bool _isBlocked = false;

  /// default wallpaper
  String _backgroundImageUrl = 'assets/images/chat_bg.png';

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _initVoiceRecorder();
    _markMessagesAsSeen();
  }

  Future<void> _initVoiceRecorder() async {
    try {
      await _voiceHandler.initRecorder();
    } catch (e) {
      debugPrint('Recorder init error: $e');
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _voiceHandler.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final typing = _messageController.text.trim().isNotEmpty;
    if (_isTyping != typing) {
      setState(() {
        _isTyping = typing;
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isBlocked) return;

    final messageText = text.trim();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'message': messageText,
      'senderId': widget.currentUserId,
      'receiverId': widget.receiverId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isSeen': false,
    });

    _messageController.clear();

    if (mounted) {
      setState(() {
        _isTyping = false;
      });
    }
  }

  Future<void> _sendAudioMessage(String audioUrl) async {
    if (audioUrl.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'message': audioUrl,
      'senderId': widget.currentUserId,
      'receiverId': widget.receiverId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'audio',
      'isSeen': false,
    });
  }

  Future<void> _toggleRecording() async {
    if (_isBlocked) return;

    try {
      if (_isRecording) {
        final audioUrl =
            await _voiceHandler.stopAndUploadRecording(widget.chatId);

        if (mounted) {
          setState(() => _isRecording = false);
        }

        if (audioUrl != null && audioUrl.isNotEmpty) {
          await _sendAudioMessage(audioUrl);
        }
      } else {
        await _voiceHandler.startRecording();
        if (mounted) {
          setState(() => _isRecording = true);
        }
      }
    } catch (e) {
      debugPrint('Recording error: $e');

      if (mounted) {
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording error: $e')),
        );
      }
    }
  }

  Future<void> _markMessagesAsSeen() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: widget.currentUserId)
          .where('isSeen', isEqualTo: false)
          .get();

      for (final doc in query.docs) {
        await doc.reference.update({'isSeen': true});
      }
    } catch (e) {
      debugPrint('Seen update error: $e');
    }
  }

  Future<void> _clearChat() async {
    try {
      final messagesRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages');

      final snapshot = await messagesRef.get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat cleared')),
        );
      }
    } catch (e) {
      debugPrint('Clear chat error: $e');
    }
  }

  Future<void> _showClearChatDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Do you want to delete all messages in this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _clearChat();
    }
  }

  Future<void> _showBlockDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_isBlocked ? 'Unblock Teacher' : 'Block Teacher'),
        content: Text(
          _isBlocked
              ? 'Do you want to unblock this teacher?'
              : 'Do you want to block this teacher?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_isBlocked ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _isBlocked = !_isBlocked;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isBlocked ? 'Teacher blocked' : 'Teacher unblocked',
          ),
        ),
      );
    }
  }

  Future<void> _showReportDialog() async {
    final controller = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report Teacher'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Write your reason...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm == true && controller.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('reports').add({
        'chatId': widget.chatId,
        'reportedUserId': widget.receiverId,
        'reportedBy': widget.currentUserId,
        'reason': controller.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted')),
        );
      }
    }
  }

  Future<void> _pickChatBackground() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) {
        setState(() {
          _backgroundImageUrl = picked.path;
        });
      }
    } catch (e) {
      debugPrint('Background picker error: $e');
    }
  }

  void _handleMenu(String value) {
    switch (value) {
      case 'background':
        _pickChatBackground();
        break;
      case 'clear':
        _showClearChatDialog();
        break;
      case 'block':
        _showBlockDialog();
        break;
      case 'report':
        _showReportDialog();
        break;
    }
  }

  Widget _buildMessageInput() {
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
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _isEmojiVisible = !_isEmojiVisible;
                        });
                      },
                      icon: Icon(
                        _isEmojiVisible
                            ? Icons.keyboard
                            : Icons.emoji_emotions_outlined,
                        color: Colors.grey[700],
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Type a message',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF128C7E),
              child: IconButton(
                onPressed: _isBlocked
                    ? null
                    : () {
                        if (_isTyping) {
                          _sendMessage(_messageController.text);
                        } else {
                          _toggleRecording();
                        }
                      },
                icon: Icon(
                  _isTyping
                      ? Icons.send
                      : (_isRecording ? Icons.stop : Icons.mic),
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedBanner() {
    if (!_isBlocked) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: Colors.red.shade50,
      child: const Text(
        'You blocked this teacher. You can unblock from the top menu.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider bgProvider =
        _backgroundImageUrl.startsWith('assets/')
            ? AssetImage(_backgroundImageUrl)
            : FileImage(File(_backgroundImageUrl));

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.teacherName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.call, color: Colors.white),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.videocam, color: Colors.white),
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenu,
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'background',
                child: Text('Change Chat Background'),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Text('Clear Chat'),
              ),
              PopupMenuItem<String>(
                value: 'block',
                child: Text(_isBlocked ? 'Unblock Teacher' : 'Block Teacher'),
              ),
              const PopupMenuItem<String>(
                value: 'report',
                child: Text('Report Teacher'),
              ),
            ],
            icon: const Icon(Icons.more_vert, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: bgProvider,
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            _buildBlockedBanner(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(widget.chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Something went wrong'),
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

                      final bool isMe =
                          data['senderId'] == widget.currentUserId;

                      return MessageBubble(
                        message: (data['message'] ?? '').toString(),
                        isMe: isMe,
                        timestamp: data['timestamp'] as Timestamp?,
                        type: (data['type'] ?? 'text').toString(),
                        messageId: doc.id,
                        isTyping: false,
                        uploadVoiceMessage: () {},
                        isSeen: data['isSeen'] ?? false,
                        isDelivered: true,
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(),
            if (_isEmojiVisible)
              SizedBox(
                height: 260,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    _messageController.text += emoji.emoji;
                    _messageController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _messageController.text.length),
                    );
                    _onTextChanged();
                  },
                  config: Config(
                    height: 260,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: EmojiViewConfig(
                      columns: 8,
                      emojiSizeMax: 28,
                      backgroundColor: Colors.white,
                    ),
                    skinToneConfig: const SkinToneConfig(),
                    categoryViewConfig: const CategoryViewConfig(),
                    bottomActionBarConfig: const BottomActionBarConfig(),
                    searchViewConfig: const SearchViewConfig(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}