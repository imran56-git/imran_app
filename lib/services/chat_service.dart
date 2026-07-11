import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chat_service.dart';
import '../../services/media_service.dart';
import '../../widgets/chat_input_bar.dart';
import '../../widgets/attachment_bottom_sheet.dart';
import '../../widgets/reply_message_widget.dart';
import '../../widgets/typing_indicator.dart';
import '../../widgets/message_bubble.dart';
import '../../models/message_model.dart';
import '../../utils/chat_colors.dart';
import 'dart:io';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String receiverId;
  final String receiverName;
  final String receiverImage;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.receiverId,
    required this.receiverName,
    required this.receiverImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final MediaService _mediaService = MediaService();
  final ScrollController _scrollController = ScrollController();
  
  MessageModel? _replyingMessage;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _chatService.markChatMessagesAsSeen(widget.chatId, widget.currentUserId);
  }

  void _handleSendMessage(String text, String type, {Map<String, dynamic>? mediaData}) {
    _chatService.sendMessage(
      chatId: widget.chatId,
      senderId: widget.currentUserId,
      receiverId: widget.receiverId,
      message: text,
      type: type,
      replyToMessageId: _replyingMessage?.messageId,
      mediaMetaData: mediaData,
    );
    if (_replyingMessage != null) {
      setState(() => _replyingMessage = null);
    }
    _scrollToBottom();
  }

  void _handleTypingStatus(bool isTyping) {
    _chatService.updateTypingStatus(widget.chatId, widget.currentUserId, isTyping);
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
        chatId: widget.chatId,
        mediaType: type,
      );
      if (url != null) {
        _handleSendMessage(url, type);
      }
    }
  }

  String _formatLastSeen(Timestamp? timestamp) {
    if (timestamp == null) return 'Offline';
    final DateTime date = timestamp.toDate();
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inHours < 1) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Last seen today at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    return 'Last seen ${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatColors.bgLight,
      appBar: AppBar(
        backgroundColor: ChatColors.appBarLight,
        leadingWidth: 70,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.only(left: 8),
            ),
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(widget.receiverImage),
            ),
          ],
        ),
        title: StreamBuilder<Map<String, dynamic>>(
          stream: _chatService.getUserStatusStream(widget.receiverId),
          builder: (context, statusSnapshot) {
            final data = statusSnapshot.data;
            final String status = data?['status'] ?? 'Offline';
            final Timestamp? lastSeen = data?['lastSeen'] as Timestamp?;

            return StreamBuilder<bool>(
              stream: _chatService.getTypingStatusStream(widget.chatId, widget.receiverId),
              builder: (context, typingSnapshot) {
                final bool isTyping = typingSnapshot.data ?? false;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.receiverName,
                      style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isTyping ? 'typing...' : (status == 'Online' ? 'Online' : _formatLastSeen(lastSeen)),
                      style: const TextStyle(fontSize: 11, color: Colors.whiteBF),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: ChatColors.primaryApp));
                }

                final docs = snapshot.data!.docs;
                _chatService.markChatMessagesAsSeen(widget.chatId, widget.currentUserId);

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: docs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return StreamBuilder<bool>(
                        stream: _chatService.getTypingStatusStream(widget.chatId, widget.receiverId),
                        builder: (context, typingSnapshot) {
                          if (typingSnapshot.data == true) {
                            return const Align(alignment: Alignment.centerLeft, child: TypingIndicator());
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    }

                    final Map<String, dynamic> data = docs[index - 1].data() as Map<String, dynamic>;
                    final message = MessageModel.fromMap(data);

                    if (message.deletedForUsers.contains(widget.currentUserId)) {
                      return const SizedBox.shrink();
                    }

                    return MessageBubble(
                      message: message,
                      isMe: message.senderId == widget.currentUserId,
                      onSwipeToReply: () {
                        setState(() => _replyingMessage = message);
                      },
                      onDeleteForMe: () => _chatService.deleteMessageForMe(widget.chatId, message.messageId, widget.currentUserId),
                      onDeleteForEveryone: () => _chatService.deleteMessageForEveryone(widget.chatId, message.messageId),
                      onReact: (emoji) => _chatService.addMessageReaction(widget.chatId, message.messageId, widget.currentUserId, emoji),
                    );
                  },
                );
              },
            ),
          ),
          if (_replyingMessage != null)
            ReplyMessageWidget(
              messageSenderName: _replyingMessage!.senderId == widget.currentUserId ? 'You' : widget.receiverName,
              messageText: _replyingMessage!.message,
              messageType: _replyingMessage!.type,
              onCancelReply: () => setState(() => _replyingMessage = null),
            ),
          ChatInputBar(
            onSendMessage: _handleSendMessage,
            onAttachmentPressed: _showAttachmentBottomSheet,
            onStartRecording: () => setState(() => _isRecording = true),
            onStopRecording: () => setState(() => _isRecording = false),
            onTypingStatusChanged: _handleTypingStatus,
            isBlocked: false,
            isRecording: _isRecording,
          ),
        ],
      ),
    );
  }
}
