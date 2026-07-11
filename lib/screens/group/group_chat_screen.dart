import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../services/media_service.dart';
import '../../widgets/chat_input_bar.dart';
import '../../widgets/attachment_bottom_sheet.dart';
import '../../widgets/reply_message_widget.dart';
import '../../widgets/message_bubble.dart';
import '../../models/message_model.dart';
import '../../utils/chat_colors.dart';

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
  final ChatService _chatService = ChatService();
  final MediaService _mediaService = MediaService();
  final ScrollController _scrollController = ScrollController();

  MessageModel? _replyingMessage;
  bool _isRecording = false;
  String _backgroundImage = 'assets/images/chat_bg.png';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  ImageProvider _buildBackgroundProvider() {
    if (_backgroundImage.startsWith('assets/')) {
      return AssetImage(_backgroundImage);
    }
    return FileImage(File(_backgroundImage));
  }

  void _handleSendMessage(String text, String type, {Map<String, dynamic>? mediaData}) {
    _chatService.sendGroupMessage(
      groupId: widget.groupId,
      senderId: widget.currentUserId,
      message: text,
      type: type,
      replyToMessageId: _replyingMessage?.messageId,
    );
    if (_replyingMessage != null) {
      setState(() => _replyingMessage = null);
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showAttachmentBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AttachmentBottomSheet(
        onDocumentTap: () => _pickAndSendMedia('document'),
        onCameraTap: () => _pickAndSendMedia('camera_image'),
        onGalleryTap: () => _pickAndSendMedia('image'),
        onAudioTap: () => _pickAndSendMedia('audio'),
        onLocationTap: () {},
        onContactTap: () {},
      ),
    );
  }

  Future<void> _pickAndSendMedia(String type) async {
    File? file;
    if (type == 'image') {
      file = await _mediaService.pickImageFromGallery();
    } else if (type == 'camera_image') {
      file = await _mediaService.captureImageFromCamera();
      type = 'image';
    } else if (type == 'document') {
      file = await _mediaService.pickDocument();
    } else if (type == 'audio') {
      file = await _mediaService.pickAudio();
    }

    if (file != null) {
      final String? url = await _mediaService.uploadMedia(
        file: file,
        chatId: widget.groupId,
        mediaType: type,
      );
      if (url != null) {
        _handleSendMessage(url, type);
      }
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
      _showEditDialog(messageId, text);
    } else if (selected == 'delete_all') {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .doc(messageId)
          .update({
        'content': 'This message was deleted',
        'type': 'text',
        'isDeletedForEveryone': true,
      });
    } else if (selected == 'delete_me') {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .doc(messageId)
          .update({
        'deletedForUsers': FieldValue.arrayUnion([widget.currentUserId]),
      });
    }
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
        'isEdited': true,
        'editTimestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatColors.bgLight,
      appBar: AppBar(
        backgroundColor: ChatColors.appBarLight,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Icon(Icons.groups, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Text(
                    'Group chat',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: _buildBackgroundProvider(),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatService.getGroupMessagesStream(widget.groupId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: ChatColors.primaryApp));
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;

                      final List<dynamic> deletedUsers = data['deletedForUsers'] ?? [];
                      if (deletedUsers.contains(widget.currentUserId)) {
                        return const SizedBox.shrink();
                      }

                      final messageText = (data['content'] ?? data['message'] ?? '').toString();
                      final type = (data['type'] ?? 'text').toString();
                      final bool isMe = data['senderId'] == widget.currentUserId;

                      final messageModel = MessageModel(
                        messageId: docs[index].id,
                        senderId: data['senderId'] ?? '',
                        receiverId: widget.groupId,
                        message: messageText,
                        type: type,
                        status: 'seen',
                        isDeletedForEveryone: data['isDeletedForEveryone'] ?? false,
                        deletedForUsers: List<String>.from(deletedUsers),
                        starredBy: List<String>.from(data['starredBy'] ?? []),
                        reactions: Map<String, String>.from(data['reactions'] ?? {}),
                        timestamp: data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : null,
                      );

                      return GestureDetector(
                        onLongPress: () => _showOptions(
                          messageId: docs[index].id,
                          text: messageText,
                          isMe: isMe,
                          type: type,
                        ),
                        child: MessageBubble(
                          message: messageModel,
                          isMe: isMe,
                          timestamp: data['timestamp'] as Timestamp?, // এখানে বাধ্যতামূলক 'timestamp' প্যারামিটারটি যুক্ত করা হলো
                          onDeleteForMe: () {},
                          onDeleteForEveryone: () {},
                          onReact: (emoji) {},
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_replyingMessage != null)
              ReplyMessageWidget(
                messageSenderName: _replyingMessage!.senderId == widget.currentUserId ? 'You' : widget.currentUserName,
                messageText: _replyingMessage!.message,
                messageType: _replyingMessage!.type,
                onCancelReply: () => setState(() => _replyingMessage = null),
              ),
            ChatInputBar(
              onSendMessage: _handleSendMessage,
              onAttachmentPressed: _showAttachmentBottomSheet,
              onStartRecording: () => setState(() => _isRecording = true),
              onStopRecording: () => setState(() => _isRecording = false),
              onTypingStatusChanged: (_) {},
              isBlocked: false,
              isRecording: _isRecording,
            ),
          ],
        ),
      ),
    );
  }
}
