import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String receiverId;
  final String receiverName;
  final String receiverProfilePic;
  final String currentUserId;
  final bool isTeacher; 

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.receiverId,
    required this.receiverName,
    required this.receiverProfilePic,
    required this.currentUserId,
    required this.isTeacher,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  Stream<List<MessageModel>>? _messageStream;

  String? _replyToMessageId;
  String? _replyToText;

  @override
  void initState() {
    super.initState();
    _initChatStream();
    _chatService.updateTypingStatus(widget.chatRoomId, widget.currentUserId, false);
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _chatService.updateTypingStatus(widget.chatRoomId, widget.currentUserId, false); 
    _scrollController.dispose(); 
    super.dispose();
  }

  void _initChatStream() {
    _messageStream = _chatService.getMessages(widget.chatRoomId);
  }

  void _markMessagesAsRead() async {
    await _chatService.markAsSeen(widget.chatRoomId, widget.currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _chatService.updateTypingStatus(widget.chatRoomId, widget.currentUserId, false);
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA), 
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF1E4C7A), 
          titleSpacing: 0,
          scrolledUnderElevation: 0,
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  _chatService.updateTypingStatus(widget.chatRoomId, widget.currentUserId, false);
                  Navigator.pop(context);
                },
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                backgroundImage: widget.receiverProfilePic.isNotEmpty
                    ? NetworkImage(widget.receiverProfilePic)
                    : null,
                child: widget.receiverProfilePic.isEmpty
                    ? const Icon(Icons.person_rounded, color: Colors.white, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.receiverName,
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white,
                        letterSpacing: 0.2
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('typing')
                          .doc(widget.chatRoomId)
                          .snapshots(),
                      builder: (context, typingSnapshot) {
                        bool isTyping = false;
                        if (typingSnapshot.hasData && typingSnapshot.data!.exists) {
                          var data = typingSnapshot.data!.data() as Map<String, dynamic>?;
                          isTyping = data?[widget.receiverId] ?? false;
                        }

                        if (isTyping) {
                          return const Text(
                            'typing...',
                            style: TextStyle(
                              fontSize: 12, 
                              color: Color(0xFFA2E8DD), 
                              fontWeight: FontWeight.bold
                            ),
                          );
                        }

                        return StreamBuilder<Map<String, dynamic>>(
                          stream: _chatService.getUserStatusStream(widget.receiverId, !widget.isTeacher),
                          builder: (context, statusSnapshot) {
                            if (statusSnapshot.hasData) {
                              bool isOnline = statusSnapshot.data!['isOnline'] ?? false;
                              return Text(
                                isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  fontSize: 11, 
                                  fontWeight: FontWeight.w500,
                                  color: isOnline ? const Color(0xFF25D366) : Colors.white70
                                ),
                              );
                            }
                            return const Text('Offline', style: TextStyle(fontSize: 11, color: Colors.white70));
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.videocam_rounded, color: Colors.white, size: 22), onPressed: () {}),
            IconButton(icon: const Icon(Icons.call_rounded, color: Colors.white, size: 22), onPressed: () {}),
            IconButton(icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22), onPressed: () {}),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: _messageStream == null
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A), strokeWidth: 3))
                  : StreamBuilder<List<MessageModel>>(
                      stream: _messageStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text(
                              'Failed to load messages.',
                              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A), strokeWidth: 3));
                        }

                        final messages = snapshot.data;

                        if (messages == null || messages.isEmpty) {
                          return Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: 14, color: Colors.black54),
                                  SizedBox(width: 6),
                                  Text(
                                    'Messages are end-to-end encrypted',
                                    style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        WidgetsBinding.instance.addPostFrameCallback((_) => _markMessagesAsRead());

                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true, 
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final bool isMe = message.senderId == widget.currentUserId;

                            return MessageBubble(
                              message: message,
                              isMe: isMe,
                              chatRoomId: widget.chatRoomId,
                              currentUserId: widget.currentUserId,
                              onReplyPressed: (repliedMessage) {
                                setState(() {
                                  _replyToMessageId = repliedMessage.messageId;
                                  _replyToText = repliedMessage.type == 'text' 
                                      ? repliedMessage.content 
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
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: ChatInputBar(
                chatRoomId: widget.chatRoomId,
                senderId: widget.currentUserId,
                receiverId: widget.receiverId,
                replyToMessageId: _replyToMessageId,
                replyToText: _replyToText,
                onCancelReply: () {
                  setState(() {
                    _replyToMessageId = null;
                    _replyToText = null;
                  });
                },
                onTypingChanged: (isTyping) {
                  _chatService.updateTypingStatus(widget.chatRoomId, widget.currentUserId, isTyping);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
