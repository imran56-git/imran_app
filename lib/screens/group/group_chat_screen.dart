import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../services/media_service.dart';
import '../../widgets/chat_input_bar.dart';
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

  String? _replyToMessageId;
  String? _replyToText;
  final String _backgroundImage = 'assets/images/chat_bg.png';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  ImageProvider? _buildBackgroundProvider() {
    try {
      if (_backgroundImage.startsWith('assets/')) {
        return AssetImage(_backgroundImage);
      }
      return FileImage(File(_backgroundImage));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgProvider = _buildBackgroundProvider();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 1.5),
              ),
              child: const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFF1E293B),
                child: Icon(Icons.groups_rounded, color: Colors.blueAccent, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.groupName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Secure Teacher Batch',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          image: bgProvider != null
              ? DecorationImage(
                  image: bgProvider,
                  fit: BoxFit.cover,
                  opacity: 0.03,
                  onError: (_, __) {},
                )
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _chatService.getGroupMessagesStream(widget.groupId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Failed to load group messages.',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.blueAccent),
                    );
                  }

                  final messages = snapshot.data;

                  if (messages == null || messages.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: const Text(
                          'Welcome to FYBTT Secure Group Chat',
                          style: TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final bool isMe = message.senderId == widget.currentUserId;

                      return MessageBubble(
                        message: message,
                        isMe: isMe,
                        chatRoomId: widget.groupId,
                        currentUserId: widget.currentUserId,
                        onReplyPressed: (repliedMsg) {
                          setState(() {
                            _replyToMessageId = repliedMsg.messageId;
                            _replyToText = repliedMsg.type == 'text'
                                ? repliedMsg.content
                                : 'Attachment';
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ChatInputBar(
                chatRoomId: widget.groupId,
                senderId: widget.currentUserId,
                receiverId: 'group',
                replyToMessageId: _replyToMessageId,
                replyToText: _replyToText,
                onCancelReply: () {
                  setState(() {
                    _replyToMessageId = null;
                    _replyToText = null;
                  });
                },
                onTypingChanged: (isTyping) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
