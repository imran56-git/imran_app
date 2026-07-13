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
  void initState() {
    super.initState();
  }

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

  void _handleSendMessage(String text, String type, {Map<String, dynamic>? mediaData}) async {
    if (text.trim().isEmpty) return;

    await _chatService.sendGroupMessage(
      groupId: widget.groupId,
      senderId: widget.currentUserId,
      message: text,
      type: type,
    );

    setState(() {
      _replyToMessageId = null;
      _replyToText = null;
    });
    
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E4C7A),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 20),
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
            opacity: 0.04,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _chatService.getGroupMessagesStream(widget.groupId), // ChatService ডাটা কাস্টিং সিঙ্ক (রুল ৪)
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Failed to load group messages.', style: TextStyle(color: Colors.red)));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A)));
                  }

                  final messages = snapshot.data;

                  if (messages == null || messages.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                        child: const Text('Welcome to Group Chat', style: TextStyle(color: Colors.black54, fontSize: 13)),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            _replyToText = repliedMsg.type == 'text' ? repliedMsg.content : 'Attachment';
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
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
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
                onTypingChanged: (isTyping) {
                  // গ্রুপে টাইপিং ইন্ডিকেটর সাইলেন্ট বা হ্যান্ডেল করা যেতে পারে
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
