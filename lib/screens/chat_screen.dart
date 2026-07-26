import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/chat_service.dart';
import '../services/chat_menu_service.dart';
import '../models/message_model.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_popup_menu.dart';
import '../widgets/block_dialog.dart';
import '../widgets/report_dialog.dart';
import '../widgets/clear_chat_dialog.dart';
import '../widgets/delete_chat_dialog.dart';
import '../utils/popup_menu_actions.dart';

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
  final ChatMenuService _chatMenuService = ChatMenuService();
  final ScrollController _scrollController = ScrollController();
  Stream<List<MessageModel>>? _messageStream;

  String? _replyToMessageId;
  String? _replyToText;
  String? _customBgImagePath;

  @override
  void initState() {
    super.initState();
    _initChatStream();
    _loadCustomTheme();
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

  Future<void> _loadCustomTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customBgImagePath = prefs.getString('chat_theme_${widget.chatRoomId}');
    });
  }

  Future<void> _changeChatThemeFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_theme_${widget.chatRoomId}', pickedFile.path);
      setState(() {
        _customBgImagePath = pickedFile.path;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat theme updated successfully')),
        );
      }
    }
  }

  void _handleMenuAction(ChatMenuAction action) {
    switch (action) {
      case ChatMenuAction.viewProfile:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Viewing profile of ${widget.receiverName}')),
        );
        break;

      case ChatMenuAction.blockUser:
        showDialog(
          context: context,
          builder: (context) => BlockDialog(
            userName: widget.receiverName,
            onConfirm: () async {
              await _chatMenuService.blockUser(widget.currentUserId, widget.receiverId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User blocked successfully')),
                );
              }
            },
          ),
        );
        break;

      case ChatMenuAction.reportUser:
        showDialog(
          context: context,
          builder: (context) => ReportDialog(
            userName: widget.receiverName,
            onConfirm: (reason) async {
              await _chatMenuService.reportUser(widget.currentUserId, widget.receiverId, reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User reported successfully')),
                );
              }
            },
          ),
        );
        break;

      case ChatMenuAction.clearChat:
        showDialog(
          context: context,
          builder: (context) => ClearChatDialog(
            onConfirm: () async {
              await _chatMenuService.clearChat(widget.chatRoomId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat cleared successfully')),
                );
              }
            },
          ),
        );
        break;

      case ChatMenuAction.deleteConversation:
        showDialog(
          context: context,
          builder: (context) => DeleteChatDialog(
            onConfirm: () async {
              await _chatMenuService.deleteConversation(widget.chatRoomId);
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
        );
        break;
    }
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
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('typing')
                          .doc(widget.chatRoomId)
                          .snapshots()
                          .handleError((error) => log('Typing Stream Error: $error')),
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
                              fontWeight: FontWeight.bold,
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
                                  color: isOnline ? const Color(0xFF25D366) : Colors.white70,
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
            // Extra Option for Changing Chat Theme from Gallery
            IconButton(
              icon: const Icon(Icons.wallpaper_rounded, color: Colors.white, size: 22),
              tooltip: 'Change Chat Theme',
              onPressed: _changeChatThemeFromGallery,
            ),
            ChatPopupMenu(onSelected: _handleMenuAction),
            const SizedBox(width: 4),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            image: _customBgImagePath != null
                ? DecorationImage(
                    image: FileImage(File(_customBgImagePath!)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: Column(
            children: [
              Expanded(
                child: _messageStream == null
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A), strokeWidth: 3))
                    : StreamBuilder<List<MessageModel>>(
                        stream: _messageStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Failed to load messages: ${snapshot.error}',
                                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                              ),
                            );
                          }

                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A), strokeWidth: 3));
                          }

                          final messages = snapshot.data ?? [];

                          if (messages.isEmpty) {
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
      ),
    );
  }
}
