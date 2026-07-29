import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
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
  final ImagePicker _imagePicker = ImagePicker();

  bool _isTyping = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
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
    if (_isUploading) return;

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
              "Send Attachment", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E4C7A)),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _attachmentTile(Icons.photo_library_rounded, "Gallery", Colors.purple, 'gallery'),
                _attachmentTile(Icons.camera_alt_rounded, "Camera", Colors.pink, 'camera'),
                _attachmentTile(Icons.description_rounded, "Document", Colors.blue, 'document'),
                _attachmentTile(Icons.audiotrack_rounded, "Audio", Colors.orange, 'audio'),
                _attachmentTile(Icons.video_library_rounded, "Video", Colors.red, 'video'),
                _attachmentTile(Icons.location_on_rounded, "Location", Colors.teal, 'location'),
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
        await _handleAttachmentPick(type);
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26, 
            backgroundColor: color.withOpacity(0.12), 
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
        ],
      ),
    );
  }

  Future<void> _handleAttachmentPick(String type) async {
    setState(() => _isUploading = true);
    try {
      if (type == 'gallery') {
        final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (image != null) {
          await _chatService.sendImageFile(
            chatRoomId: widget.chatRoomId,
            senderId: widget.senderId,
            receiverId: widget.receiverId,
            file: File(image.path),
          );
        }
      } else if (type == 'camera') {
        final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 80);
        if (image != null) {
          await _chatService.sendImageFile(
            chatRoomId: widget.chatRoomId,
            senderId: widget.senderId,
            receiverId: widget.receiverId,
            file: File(image.path),
          );
        }
      } else if (type == 'video') {
        final XFile? video = await _imagePicker.pickVideo(source: ImageSource.gallery);
        if (video != null) {
          await _chatService.sendVideoFile(
            chatRoomId: widget.chatRoomId,
            senderId: widget.senderId,
            receiverId: widget.receiverId,
            file: File(video.path),
          );
        }
      } else if (type == 'document') {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'zip'],
        );
        if (result != null && result.files.single.path != null) {
          await _chatService.sendDocumentFile(
            chatRoomId: widget.chatRoomId,
            senderId: widget.senderId,
            receiverId: widget.receiverId,
            file: File(result.files.single.path!),
            fileName: result.files.single.name,
          );
        }
      } else if (type == 'audio') {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
        if (result != null && result.files.single.path != null) {
          await _chatService.sendAudioFile(
            chatRoomId: widget.chatRoomId,
            senderId: widget.senderId,
            receiverId: widget.receiverId,
            file: File(result.files.single.path!),
          );
        }
      } else if (type == 'location') {
        // Shared location with fallback values
        await _chatService.sendLocation(
          widget.chatRoomId, 
          widget.senderId, 
          widget.receiverId, 
          22.5726, 
          88.3639,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send attachment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isUploading) return;

    final String? currentReplyId = widget.replyToMessageId;

    _controller.clear();
    setState(() => _isTyping = false);
    widget.onTypingChanged(false);
    _chatService.updateTypingStatus(widget.chatRoomId, widget.senderId, false);

    if (widget.onCancelReply != null) {
      widget.onCancelReply!();
    }

    try {
      await _chatService.sendMessage(
        chatId: widget.chatRoomId,
        senderId: widget.senderId,
        receiverId: widget.receiverId,
        message: text,
        type: 'text',
        replyToMessageId: currentReplyId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _handleMicTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice recording feature coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isUploading)
          const LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E4C7A)),
          ),
        if (widget.replyToMessageId != null && widget.replyToText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: const Border(left: BorderSide(color: Color(0xFF1E4C7A), width: 4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Replying to Message",
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: Color(0xFF1E4C7A), 
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.replyToText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.black.withOpacity(0.87), fontSize: 13),
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
                          enabled: !_isUploading,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 4),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file_rounded, color: Colors.grey),
                        onPressed: _isUploading ? null : _showAttachmentBottomSheet,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6.0),
              GestureDetector(
                onTap: _isTyping ? _handleSend : _handleMicTap,
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF1E4C7A),
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
