import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/gemini_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  bool? isLiked; // true = liked, false = disliked, null = no reaction

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isLiked,
  });
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

  // Speech-to-Text & Text-to-Speech Variables
  late stt.SpeechToText _speechToText;
  late FlutterTts _flutterTts;
  
  bool _isListening = false;
  bool _isLoading = false;
  bool _isSelectionMode = false;
  int? _currentlySpeakingIndex;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _initTts();
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _currentlySpeakingIndex = null;
      });
    });
    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _currentlySpeakingIndex = null;
      });
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _controller.dispose();
    super.dispose();
  }

  // STEP 1: Text cleaner function
  String _cleanText(String text) {
    return text.replaceAll('**', '').replaceAll('* ', '• ');
  }

  // AI Response Request & Stop Logic
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (_isListening) {
      _stopListening();
    }

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    final response = await _geminiService.sendChatMessage(text);

    if (!mounted || !_isLoading) return; // _isLoading false মানে ইউজার স্টপ বাটনে চাপ দিয়েছেন

    final cleanedResponse = _cleanText(response ?? "An unexpected error occurred.");

    setState(() {
      _isLoading = false;
      _messages.add(ChatMessage(
        text: cleanedResponse,
        isUser: false,
      ));
    });
  }

  // Stop Generating Response Logic
  void _stopGenerating() {
    setState(() {
      _isLoading = false;
    });
  }

  // STEP 4: Voice Input Logic (STT)
  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (_) {
          setState(() => _isListening = false);
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (val) {
            setState(() {
              _controller.text = val.recognizedWords;
            });
          },
        );
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() {
    _speechToText.stop();
    setState(() => _isListening = false);
  }

  // STEP 5: Voice Output Logic (TTS)
  Future<void> _toggleSpeak(int index, String text) async {
    if (_currentlySpeakingIndex == index) {
      await _flutterTts.stop();
      setState(() {
        _currentlySpeakingIndex = null;
      });
    } else {
      await _flutterTts.stop();
      setState(() {
        _currentlySpeakingIndex = index;
      });
      await _flutterTts.speak(text);
    }
  }

  // STEP 6: Copy Text Logic
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Copied to clipboard"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Selection & Message Delete Management
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
              _flutterTts.stop();
              setState(() {
                _messages.clear();
                _selectedIndices.clear();
                _isSelectionMode = false;
                _currentlySpeakingIndex = null;
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
      backgroundColor: Colors.white,
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
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E4C7A).withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            size: 40,
                            color: Color(0xFF1E4C7A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ask FYBTT AI anything',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Search teachers, courses or get instant study help',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isSelected = _selectedIndices.contains(index);
                      final isSpeaking = _currentlySpeakingIndex == index;

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
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E4C7A).withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: const Color(0xFF1E4C7A), width: 1.5)
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: message.isUser
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
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
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E4C7A).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome,
                                    size: 18,
                                    color: Color(0xFF1E4C7A),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Flexible(
                                child: message.isUser
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF1E4C7A),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(18),
                                            topRight: Radius.circular(18),
                                            bottomLeft: Radius.circular(18),
                                            bottomRight: Radius.circular(4),
                                          ),
                                        ),
                                        child: Text(
                                          message.text,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            height: 1.4,
                                          ),
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              message.text,
                                              style: const TextStyle(
                                                color: Color(0xFF1E293B),
                                                fontSize: 15,
                                                height: 1.5,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          // STEP 5 & STEP 6: Interaction Bar (TTS, Copy, Like, Dislike)
                                          Row(
                                            children: [
                                              IconButton(
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.only(right: 12),
                                                icon: Icon(
                                                  isSpeaking
                                                      ? Icons.volume_up_rounded
                                                      : Icons.volume_mute_rounded,
                                                  size: 18,
                                                  color: isSpeaking
                                                      ? const Color(0xFF1E4C7A)
                                                      : Colors.grey.shade500,
                                                ),
                                                onPressed: () => _toggleSpeak(index, message.text),
                                                tooltip: isSpeaking ? 'Stop Audio' : 'Listen',
                                              ),
                                              IconButton(
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.only(right: 12),
                                                icon: Icon(
                                                  Icons.copy_rounded,
                                                  size: 16,
                                                  color: Colors.grey.shade500,
                                                ),
                                                onPressed: () => _copyToClipboard(message.text),
                                                tooltip: 'Copy',
                                              ),
                                              IconButton(
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.only(right: 12),
                                                icon: Icon(
                                                  message.isLiked == true
                                                      ? Icons.thumb_up_rounded
                                                      : Icons.thumb_up_outlined,
                                                  size: 16,
                                                  color: message.isLiked == true
                                                      ? const Color(0xFF1E4C7A)
                                                      : Colors.grey.shade500,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    message.isLiked = message.isLiked == true ? null : true;
                                                  });
                                                },
                                                tooltip: 'Like',
                                              ),
                                              IconButton(
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.only(right: 12),
                                                icon: Icon(
                                                  message.isLiked == false
                                                      ? Icons.thumb_down_rounded
                                                      : Icons.thumb_down_outlined,
                                                  size: 16,
       color: message.isLiked == false
                                                      ? Colors.red.shade400
                                                      : Colors.grey.shade500,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    message.isLiked = message.isLiked == false ? null : false;
                                                  });
                                                },
                                                tooltip: 'Dislike',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ),
                              if (message.isUser) ...[
                                const SizedBox(width: 8),
                                const CircleAvatar(
                                  backgroundColor: Color(0xFF34495E),
                                  radius: 14,
                                  child: Icon(Icons.person, size: 16, color: Colors.white),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isLoading) const _ThinkingIndicator(),
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
                      enabled: !_isLoading, // এআই উত্তর তৈরি করার সময় ইনপুট ডিসেবল থাকবে
                      decoration: InputDecoration(
                        hintText: _isLoading
                            ? 'Generating response...'
                            : (_isListening ? 'Listening...' : 'Ask FYBTT AI...'),
                        hintStyle: TextStyle(
                          color: _isListening ? Colors.red.shade400 : Colors.grey.shade400,
                          fontSize: 14,
                        ),
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
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isListening ? Colors.red : const Color(0xFF1E4C7A),
                      size: 24,
                    ),
                    onPressed: _isLoading ? null : _toggleListening,
                    tooltip: 'Voice Input',
                  ),
                  const SizedBox(width: 2),
                  // STOP / SEND Dynamic Button
                  CircleAvatar(
                    backgroundColor: _isLoading ? Colors.red.shade600 : const Color(0xFF1E4C7A),
                    radius: 20,
                    child: IconButton(
                      icon: Icon(
                        _isLoading ? Icons.stop_rounded : Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _isLoading ? _stopGenerating : _sendMessage,
                      tooltip: _isLoading ? 'Stop' : 'Send',
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

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          FadeTransition(
            opacity: _animation,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E4C7A).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 18,
                color: Color(0xFF1E4C7A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FadeTransition(
            opacity: _animation,
            child: Text(
              'Thinking...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}   