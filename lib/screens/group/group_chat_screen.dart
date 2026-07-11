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
  final String _backgroundImage = 'assets/images/chat_bg.png';

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (isMe && type == 'text')
                ListTile(
                  leading: Icon(Icons.edit, color: Colors.blue[800]),
                  title: const Text('Edit Message', style: TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete for me', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(context, 'delete_me'),
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                  title: const Text('Delete for everyone', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Message', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Update your message',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[800]!, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
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
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        elevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.2),
                  ),
                  Text(
                    'Tap for group info',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F9),
          image: DecorationImage(
            image: _buildBackgroundProvider(),
            fit: BoxFit.cover,
            opacity: 0.06,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatService.getGroupMessagesStream(widget.groupId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator(color: Colors.blue[800]));
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: MessageBubble(
                            message: messageModel,
                            isMe: isMe,
                            timestamp: data['timestamp'] as Timestamp?,
                            messageId: messageModel.messageId,
                            type: type,
                            isTyping: false,
                            uploadVoiceMessage: () {}, // <--- এখানে নতুন রিকোয়ার্ড প্যারামিটারটি যুক্ত করা হলো
                            onDeleteForMe: () {},
                            onDeleteForEveryone: () {},
                            onReact: (emoji) {},
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_replyingMessage != null)
              Container(
                color: Colors.white,
                child: ReplyMessageWidget(
                  messageSenderName: _replyingMessage!.senderId == widget.currentUserId ? 'You' : widget.currentUserName,
                  messageText: _replyingMessage!.message,
                  messageType: _replyingMessage!.type,
                  onCancelReply: () => setState(() => _replyingMessage = null),
                ),
              ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -1),
                  )
                ]
              ),
              child: ChatInputBar(
                onSendMessage: _handleSendMessage,
                onAttachmentPressed: _showAttachmentBottomSheet,
                onStartRecording: () => setState(() => _isRecording = true),
                onStopRecording: () => setState(() => _isRecording = false),
                onTypingStatusChanged: (_) {},
                isBlocked: false,
                isRecording: _isRecording,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
