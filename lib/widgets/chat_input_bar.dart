import 'package:flutter/material.dart';

class ChatInputBar extends StatefulWidget {
  final String chatRoomId;
  final String senderId;
  final String receiverId;
  final Function(bool) onTypingChanged;

  const ChatInputBar({
    super.key,
    required this.chatRoomId,
    required this.senderId,
    required this.receiverId,
    required this.onTypingChanged,
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
      widget.onTypingChanged(_isTyping); // রিয়াল-টাইম টাইপিং ট্র্যাকার ট্রিগার
    }
  }

  // হোয়াটসঅ্যাপ স্টাইল ফাইল ম্যানেজার এটাচমেন্ট শিট (রিকোয়ারমেন্ট ২)
  void _showAttachmentBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Send Document / Media", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _attachmentTile(Icons.image, "Gallery", Colors.purple),
                _attachmentTile(Icons.description, "Document", Colors.blue),
                _attachmentTile(Icons.audiotrack, "Audio", Colors.orange),
                _attachmentTile(Icons.video_library, "Video", Colors.red),
                _attachmentTile(Icons.folder_zip, "ZIP/RAR", Colors.teal),
                _attachmentTile(Icons.android, "APK File", Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentTile(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        // এখানে আপনার ব্যাকএন্ড ফাইল আপলোডার কানেক্ট হবে
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(radius: 26, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    // এখানে ডাইরেক্ট চ্যাট সার্ভিস মেসেজ পুশ মেথড ট্রিগার হবে
    _controller.clear();
    setState(() => _isTyping = false);
    widget.onTypingChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25.0),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 1))],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                    onPressed: () {}, // ইমোজি পিকার পপআপ
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
                  // রিকোয়ারমেন্ট ২ ফিক্স: গ্যালারি আইকন এখানে দেওয়া হয়েছে যা বটম শিট ট্রিগার করবে
                  IconButton(
                    icon: const Icon(Icons.collections_rounded, color: Colors.grey),
                    onPressed: _showAttachmentBottomSheet,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6.0),
          
          // ডাইনামিক অ্যাকশন বাটন (টাইপিং মোডে সেন্ড আইকন / আইডল মোডে মাইক্রোফোন রেকর্ড আইকন)
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
    );
  }
}
