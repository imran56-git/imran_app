import 'package:flutter/material.dart';
import '../services/gemini_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final List<ChatMessage> _messages = [];
  final Set<int> _selectedIndices = {};
  bool _isLoading = false;
  bool _isSelectionMode = false;

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    final response = await _geminiService.sendChatMessage(text);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _messages.add(ChatMessage(
        text: response ?? "An unexpected error occurred.",
        isUser: false,
      ));
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _enterSelectionMode(int index) {
    setState(() {
      _isSelectionMode = true;
      _selectedIndices.add(index);
    });
  }

  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  void _deleteSelectedMessages() {
    setState(() {
      final sortedIndices = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
      for (int index in sortedIndices) {
        if (index < _messages.length) {
          _messages.removeAt(index);
        }
      }
      _selectedIndices.clear();
      _isSelectionMode = false;
    });
  }

  void _clearAllMessages() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Conversation"),
        content: const Text("Are you sure you want to delete all messages?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _messages.clear();
                _selectedIndices.clear();
                _isSelectionMode = false;
              });
              _geminiService.resetChat();
            },
            child: const Text("Clear All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E4C7A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: _isSelectionMode
            ? Text('${_selectedIndices.length} Selected')
            : const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 20, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    'FYBTT AI Assistant',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: _deleteSelectedMessages,
                  tooltip: 'Delete Selected',
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _clearSelection,
                  tooltip: 'Cancel',
                ),
              ]
            : [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'clear') {
                      _clearAllMessages();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Clear All Chat', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Ask FYBTT AI anything',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isSelected = _selectedIndices.contains(index);

                      return GestureDetector(
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _enterSelectionMode(index);
                          }
                        },
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(index);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected ? Border.all(color: const Color(0xFF1E4C7A), width: 1.5) : null,
                          ),
                          child: Row(
                            mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isSelectionMode) ...[
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleSelection(index),
                                  activeColor: const Color(0xFF1E4C7A),
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (!message.isUser) ...[
                                const CircleAvatar(
                                  backgroundColor: Color(0xFF1E4C7A),
                                  radius: 16,
                                  child: Icon(Icons.smart_toy_rounded, size: 18, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: message.isUser ? const Color(0xFF1E4C7A) : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      if (!message.isUser)
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                    ],
                                  ),
                                  child: Text(
                                    message.text,
                                    style: TextStyle(
                                      color: message.isUser ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                              if (message.isUser) ...[
                                const SizedBox(width: 8),
                                const CircleAvatar(
                                  backgroundColor: Color(0xFF34495E),
                                  radius: 16,
                                  child: Icon(Icons.person, size: 18, color: Colors.white),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask FYBTT AI...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF1E4C7A),
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
