import 'package:flutter/material.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String, String) onSendMessage;
  final VoidCallback onAttachmentPressed;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final Function(bool) onTypingStatusChanged;
  final bool isBlocked;
  final bool isRecording;

  const ChatInputBar({
    super.key,
    required this.onSendMessage,
    required this.onAttachmentPressed,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onTypingStatusChanged,
    required this.isBlocked,
    required this.isRecording,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final bool typing = _controller.text.trim().isNotEmpty;
    if (_isTyping != typing) {
      setState(() => _isTyping = typing);
      widget.onTypingStatusChanged(_isTyping);
    }
  }

  void _handleSend() {
    if (_controller.text.trim().isEmpty || widget.isBlocked) return;
    widget.onSendMessage(_controller.text.trim(), 'text');
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isBlocked) {
      return const SizedBox.shrink();
    }

    return Padding(
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
                    color: Colors.black.withAlpha(13),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
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
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: widget.onAttachmentPressed,
                  ),
                  if (!_isTyping)
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.grey),
                      onPressed: () {},
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6.0),
          GestureDetector(
            onTap: _isTyping ? _handleSend : null,
            onLongPress: !_isTyping ? widget.onStartRecording : null,
            onLongPressUp: !_isTyping ? widget.onStopRecording : null,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF00A884),
              child: Icon(
                _isTyping
                    ? Icons.send
                    : (widget.isRecording ? Icons.stop : Icons.mic),
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
