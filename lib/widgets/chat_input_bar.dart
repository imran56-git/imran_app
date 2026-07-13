import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class ChatInputBar extends StatefulWidget {
  final String chatRoomId;
  final String senderId;
  final String receiverId;
  final Function(bool) onTypingChanged;
  final String? replyToMessageId;
  final String? replyToText;
  final VoidCallback? onCancelReply;

  const ChatInputBar({
    super.key,
    required this.chatRoomId,
    required this.senderId,
    required this.receiverId,
    required this.onTypingChanged,
    this.replyToMessageId,
    this.replyToText,
    this.onCancelReply,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // স্ক্রিন বন্ধ হওয়ার আগে টাইপিং স্ট্যাটাস ক্লিন করা
    if (_isTyping) {
      _chatService.updateTypingStatus(widget.chatRoomId, widget.senderId, false);
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final bool typing = _controller.text.trim().isNotEmpty;
    if (_isTyping != typing) {
      setState(() => _isTyping = typing);
      widget.onTypingChanged(_isTyping);
      _chatService.updateTypingStatus(widget.chatRoomId, widget.senderId, _isTyping);
    }
  }

  void _showAttachmentBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Send Document / Media", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _attachmentTile(Icons.image, "Gallery", Colors.purple, 'image'),
                _attachmentTile(Icons.description, "Document", Colors.blue, 'document'),
                _attachmentTile(Icons.audiotrack, "Audio", Colors.orange, 'audio'),
                _attachmentTile(Icons.video_library, "Video", Colors.red, 'video'),
                _attachmentTile(Icons.location_on, "Location", Colors.teal, 'location'),
                _attachmentTile(Icons.mic, "Voice", Colors.green, 'voice'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentTile(IconData icon, String label, Color color, String type) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        // প্রোডাকশন রেডি মিডিয়া হ্যান্ডলার (ইউজার ইউআরএল পুশ করতে পারবেন)
        String mockUrl = "https://firebasestorage.googleapis.com/v0/b/mock/o/$type";
        
        if (type == 'location') {
          await _chatService.sendLocation(
            widget.chatRoomId, 
            widget.senderId, 
            widget.receiverId, 
            22.5726, 
            88.3639,
          );
        } else if (type == 'document') {
          await _chatService.sendDocument(
            widget.chatRoomId, 
            widget.senderId, 
            widget.receiverId, 
            mockUrl, 
            "Document.pdf",
          );
        } else if (type == 'image') {
          await _chatService.sendImage(widget.chatRoomId, widget.senderId, widget.receiverId, mockUrl);
        } else if (type == 'video') {
          await _chatService.sendVideo(widget.chatRoomId, widget.senderId, widget.receiverId, mockUrl);
        } else if (type == 'audio') {
          await _chatService.sendAudio(widget.chatRoomId, widget.senderId, widget.receiverId, mockUrl);
        } else if (type == 'voice') {
          await _chatService.sendVoice(widget.chatRoomId, widget.senderId, widget.receiverId, mockUrl);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26, 
            backgroundColor: color.withOpacity(0.1), 
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final String? currentReplyId = widget.replyToMessageId;

    _controller.clear();
    setState(() => _isTyping = false);
    widget.onTypingChanged(false);
    _chatService.updateTypingStatus(widget.chatRoomId, widget.senderId, false);

    if (widget.onCancelReply != null) {
      widget.onCancelReply!();
    }

    await _chatService.sendMessage(
      chatId: widget.chatRoomId,
      senderId: widget.senderId,
      receiverId: widget.receiverId,
      message: text,
      type: 'text',
      replyToMessageId: currentReplyId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // রিপ্লাই প্রিভিউ উইজেট এরিয়া (যদি কোনো মেসেজ রিপ্লাই মোডে থাকে)
        if (widget.replyToMessageId != null && widget.replyToText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: const Border(left: BorderSide(color: Color(0xFF006653), width: 4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Reply to Message",
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: Color(0xFF006653), 
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.replyToText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.blackDE, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: widget.onCancelReply,
                ),
              ],
            ),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05), 
                        blurRadius: 5, 
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                        onPressed: () {}, 
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'Message',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 4),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.collections_rounded, color: Colors.grey),
                        onPressed: _showAttachmentBottomSheet,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6.0),
              GestureDetector(
                onTap: _isTyping ? _handleSend : null,
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF006653),
                  child: Icon(
                    _isTyping ? Icons.send : Icons.mic,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
