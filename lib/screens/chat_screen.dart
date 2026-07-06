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
  final ScrollController _scrollController = ScrollController();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final ImagePicker _picker = ImagePicker();
  final VoiceMessageHandler _voiceHandler = VoiceMessageHandler();

  bool _isRecording = false;
  bool _isEmojiVisible = false;
  bool _isTyping = false;
  bool _isUploadingImage = false;

  String _backgroundImageUrl = "assets/chat_bg.png";

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _messageController.addListener(_onTextChanged);
    _markMessagesAsSeen();
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  void _onTextChanged() {
    final isNowTyping = _messageController.text.trim().isNotEmpty;
    if (_isTyping != isNowTyping) {
      setState(() {
        _isTyping = isNowTyping;
      });
    }
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status == PermissionStatus.granted) {
      await _recorder.openRecorder();
    }
  }

  Future<void> _markMessagesAsSeen() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('senderId', isEqualTo: widget.receiverId)
          .where('isSeen', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.update({'isSeen': true});
      }
    } catch (_) {}
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final cleanText = text.trim();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'message': cleanText,
      'senderId': widget.currentUserId,
      'receiverId': widget.receiverId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isSeen': false,
    });

    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
      'lastMessage': cleanText,
      'lastMessageType': 'text',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': [widget.currentUserId, widget.receiverId],
    }, SetOptions(merge: true));

    _messageController.clear();

    setState(() {
      _isTyping = false;
    });

    _scrollToBottom();
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      /// For now we are sending the local path directly.
      /// If you already upload to Firebase Storage elsewhere,
      /// replace `picked.path` with uploaded image URL.
      final imagePath = picked.path;

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
        'isSeen': false,
      });

      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
        'lastMessage': '📷 Photo',
        'lastMessageType': 'image',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'participants': [widget.currentUserId, widget.receiverId],
      }, SetOptions(merge: true));

      _scrollToBottom();
    } catch (e) {
      _showSnackBar('Failed to send image');
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final String? localPath = await _recorder.stopRecorder();

        setState(() => _isRecording = false);

        String finalAudioPath = localPath ?? '';

        try {
          final uploadedUrl =
              await _voiceHandler.stopAndUploadRecording(widget.chatId);
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            finalAudioPath = uploadedUrl;
          }
        } catch (_) {}

        if (finalAudioPath.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .collection('messages')
              .add({
            'message': finalAudioPath,
            'senderId': widget.currentUserId,
            'receiverId': widget.receiverId,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'audio',
            'isSeen': false,
          });

          await FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .set({
            'lastMessage': '🎤 Voice message',
            'lastMessageType': 'audio',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'participants': [widget.currentUserId, widget.receiverId],
          }, SetOptions(merge: true));

          _scrollToBottom();
        }
      } else {
        final micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          _showSnackBar('Microphone permission denied');
          return;
        }

        await _recorder.startRecorder(toFile: 'audio_msg.aac');
        setState(() => _isRecording = true);
      }
    } catch (e) {
      _showSnackBar('Voice recording failed');
      if (mounted) {
        setState(() => _isRecording = false);
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleEmojiKeyboard() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isEmojiVisible = !_isEmojiVisible;
    });
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Send image'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.wallpaper_outlined),
                  title: const Text('Change chat wallpaper'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSnackBar('Wallpaper feature is ready to connect');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block_outlined, color: Colors.red),
                  title: const Text(
                    'Block teacher',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showSnackBar('Block action ready');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Clear chat',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showSnackBar('Clear chat action ready');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Wrap(
              runSpacing: 10,
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.photo, color: Color(0xFF0B93F6)),
                  ),
                  title: const Text('Gallery'),
                  subtitle: const Text('Send photo from gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndSendImage();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.camera_alt, color: Color(0xFF128C7E)),
                  ),
                  title: const Text('Camera'),
                  subtitle: const Text('Capture and send a photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      final XFile? picked = await _picker.pickImage(
                        source: ImageSource.camera,
                      );
                      if (picked == null) return;

                      setState(() => _isUploadingImage = true);

                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.chatId)
                          .collection('messages')
                          .add({
                        'message': picked.path,
                        'senderId': widget.currentUserId,
                        'receiverId': widget.receiverId,
                        'timestamp': FieldValue.serverTimestamp(),
                        'type': 'image',
                        'isSeen': false,
                      });

                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.chatId)
                          .set({
                        'lastMessage': '📷 Photo',
                        'lastMessageType': 'image',
                        'lastMessageTime': FieldValue.serverTimestamp(),
                        'participants': [
                          widget.currentUserId,
                          widget.receiverId,
                        ],
                      }, SetOptions(merge: true));

                      _scrollToBottom();
                    } catch (_) {
                      _showSnackBar('Failed to capture image');
                    } finally {
                      if (mounted) {
                        setState(() => _isUploadingImage = false);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Widget _buildChatAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF075E54),
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white24,
            child: Text(
              widget.teacherName.isNotEmpty
                  ? widget.teacherName[0].toUpperCase()
                  : 'T',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.teacherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isRecording ? 'Recording voice message...' : 'Online',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            _showSnackBar('Search in chat coming next');
          },
          icon: const Icon(Icons.search, color: Colors.white),
        ),
        IconButton(
          onPressed: _showChatOptions,
          icon: const Icon(Icons.more_vert, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
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

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Failed to load messages',
                style: TextStyle(color: Colors.black54),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Start the conversation by sending a message.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.only(top: 8, bottom: 10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              bool isMe = data['senderId'] == widget.currentUserId;

              return MessageBubble(
                message: data['message'] ?? '',
                isMe: isMe,
                timestamp: data['timestamp'] as Timestamp?,
                type: data['type'] ?? 'text',
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
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: _toggleEmojiKeyboard,
                      icon: Icon(
                        _isEmojiVisible
                            ? Icons.keyboard_alt_outlined
                            : Icons.emoji_emotions_outlined,
                        color: Colors.grey.shade700,
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
                          isCollapsed: true,
                        ),
                        onTap: () {
                          if (_isEmojiVisible) {
                            setState(() => _isEmojiVisible = false);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: _showAttachmentSheet,
                      icon: Icon(
                        Icons.attach_file,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    IconButton(
                      onPressed: _pickAndSendImage,
                      icon: Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF075E54),
              child: _isUploadingImage
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
      