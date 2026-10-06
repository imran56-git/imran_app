import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import '../services/ai_coordinator_service.dart';
import '../services/tts_voice_service.dart';
import '../utils/ai_cooldown_manager.dart';

class ChatMessage {
  String text;
  final bool isUser;
  final DateTime timestamp;
  bool? isLiked;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isLiked,
  });
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiCoordinatorService _coordinatorService = AiCoordinatorService();
  final TtsVoiceService _ttsVoiceService = TtsVoiceService();
  final AiCooldownManager _cooldownManager = AiCooldownManager();
  final List<ChatMessage> _messages = [];
  final Set<int> _selectedIndices = {};

  late stt.SpeechToText _speechToText;
  StreamSubscription<String>? _streamSubscription;
  Timer? _typewriterTimer;
  final StringBuffer _incomingBuffer = StringBuffer();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isListening = false;
  bool _isLoading = false;
  bool _isSelectionMode = false;
  bool _isFallbackActive = false;
  int? _currentlySpeakingIndex;

  static const Color primaryNavy = Color(0xFF1E3A8A);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color userBubbleColor = Color(0xFF1D4ED8);
  static const Color scaffoldBg = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _initAnimations();
    _initServices();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initServices() {
    _ttsVoiceService.initTts();
    _ttsVoiceService.onComplete = () {
      if (mounted) setState(() => _currentlySpeakingIndex = null);
    };
    _ttsVoiceService.onError = () {
      if (mounted) setState(() => _currentlySpeakingIndex = null);
    };
    _cooldownManager.init();
    _cooldownManager.addListener(_onCooldownTick);
  }

  void _onCooldownTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _typewriterTimer?.cancel();
    _pulseController.dispose();
    _cooldownManager.removeListener(_onCooldownTick);
    _ttsVoiceService.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading || _cooldownManager.isInCooldown) return;

    if (_isListening) _stopListening();

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
      _isFallbackActive = false;
    });
    _scrollToBottom();

    final aiMessage = ChatMessage(
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(aiMessage);
    });

    _incomingBuffer.clear();
    _startTypewriter(aiMessage);

    try {
      final stream = _coordinatorService.sendMessageStream(
        text,
        onFallbackStatus: (isActive) {
          if (mounted) {
            setState(() {
              _isFallbackActive = isActive && aiMessage.text.isEmpty;
            });
          }
        },
      );

      _streamSubscription = stream.listen(
        (chunk) {
          if (_isFallbackActive && mounted) {
            setState(() => _isFallbackActive = false);
          }
          _incomingBuffer.write(chunk);
        },
        onError: (_) {
          if (mounted) {
            setState(() => _isFallbackActive = false);
          }
          _incomingBuffer.write('\n⚠️ Connection error.');
          _stopGenerating();
        },
        onDone: () {
          _drainBufferAndFinish();
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isFallbackActive = false);
      }
      _incomingBuffer.write('\n⚠️ Unable to connect.');
      _stopGenerating();
    }
  }

  void _startTypewriter(ChatMessage aiMessage) {
    _typewriterTimer?.cancel();
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 14), (timer) {
      if (_incomingBuffer.isNotEmpty) {
        final current = _incomingBuffer.toString();
        final chunkSize = current.length > 25 ? 3 : (current.length > 8 ? 2 : 1);
        final addText = current.substring(0, chunkSize);
        _incomingBuffer.clear();
        _incomingBuffer.write(current.substring(chunkSize));

        if (mounted) {
          setState(() {
            aiMessage.text += addText;
            if (_isFallbackActive) _isFallbackActive = false;
          });
          _scrollToBottom();
        }
      } else if (!_isLoading) {
        timer.cancel();
      }
    });
  }

  void _drainBufferAndFinish() {
    Timer.periodic(const Duration(milliseconds: 25), (t) {
      if (_incomingBuffer.isEmpty) {
        t.cancel();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isFallbackActive = false;
          });
        }
      }
    });
  }

  void _stopGenerating() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _typewriterTimer?.cancel();
    _incomingBuffer.clear();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isFallbackActive = false;
      });
    }
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
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

  Future<void> _handleLinkTap(String? href, String text) async {
    if (href == null || href.isEmpty) return;

    try {
      final uri = Uri.parse(href);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _copyToClipboard(text);
      }
    } catch (_) {
      _copyToClipboard(text);
    }
  }

  Future<void> _toggleSpeak(int index, String text) async {
    if (_currentlySpeakingIndex == index) {
      await _ttsVoiceService.stop();
      setState(() => _currentlySpeakingIndex = null);
    } else {
      await _ttsVoiceService.stop();
      setState(() => _currentlySpeakingIndex = index);
      await _ttsVoiceService.speak(text);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text("Copied to clipboard"),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIndices.add(index);
      }
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
      final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
      for (int i in sorted) {
        if (i < _messages.length) _messages.removeAt(i);
      }
      _selectedIndices.clear();
      _isSelectionMode = false;
    });
  }

  void _clearAllMessages() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete all messages?",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            "All messages in this conversation will be permanently deleted."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _ttsVoiceService.stop();
              setState(() {
                _messages.clear();
                _selectedIndices.clear();
                _isSelectionMode = false;
                _currentlySpeakingIndex = null;
              });
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildInteractionBar(int index, ChatMessage message, bool isSpeaking) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(
            icon: isSpeaking ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
            color: isSpeaking ? accentBlue : const Color(0xFF94A3B8),
            onTap: () => _toggleSpeak(index, message.text),
          ),
          const SizedBox(width: 14),
          _buildActionButton(
            icon: Icons.copy_rounded,
            color: const Color(0xFF94A3B8),
            onTap: () => _copyToClipboard(message.text),
          ),
          const SizedBox(width: 14),
          _buildActionButton(
            icon: message.isLiked == true
                ? Icons.thumb_up_rounded
                : Icons.thumb_up_outlined,
            color: message.isLiked == true ? accentBlue : const Color(0xFF94A3B8),
            onTap: () {
              setState(() =>
                  message.isLiked = message.isLiked == true ? null : true);
            },
          ),
          const SizedBox(width: 14),
          _buildActionButton(
            icon: message.isLiked == false
                ? Icons.thumb_down_rounded
                : Icons.thumb_down_outlined,
            color: message.isLiked == false
                ? Colors.red.shade400
                : const Color(0xFF94A3B8),
            onTap: () {
              setState(() =>
                  message.isLiked = message.isLiked == false ? null : false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({required bool isAi}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isAi
            ? const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF64748B), Color(0xFF334155)],
              ),
      ),
      child: Icon(
        isAi ? Icons.auto_awesome : Icons.person,
        size: 16,
        color: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryNavy.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, size: 44, color: accentBlue),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ask FYBTT AI Assistant',
              style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Find qualified teachers, ask academic questions, or get immediate support.',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingFallbackIndicator() {
    if (!_isFallbackActive) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: FadeTransition(
        opacity: _pulseAnimation,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Connecting to FYBTT backup AI engine...',
              style: TextStyle(
                color: Color(0xFFB45309),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCooldownBanner() {
    if (!_cooldownManager.isInCooldown) return const SizedBox.shrink();

    final isDaily = _cooldownManager.isDailyQuota;
    final timeStr = _cooldownManager.formattedRemainingTime;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDaily ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDaily ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDaily ? Icons.hourglass_bottom_rounded : Icons.timer_outlined,
            color: isDaily ? Colors.red.shade700 : Colors.amber.shade800,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isDaily
                  ? 'Daily free quota reached. Time remaining: $timeStr'
                  : 'Traffic limit active. Please wait: $timeStr',
              style: TextStyle(
                color: isDaily ? Colors.red.shade900 : Colors.amber.shade900,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final bool isBlocked = _isLoading || _cooldownManager.isInCooldown;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !isBlocked,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: _cooldownManager.isInCooldown
                              ? 'Cooldown active (${_cooldownManager.formattedRemainingTime})...'
                              : (_isLoading
                                  ? 'Generating response...'
                                  : (_isListening
                                      ? 'Listening...'
                                      : 'Type your question...')),
                          hintStyle: TextStyle(
                            color:
                                _isListening ? Colors.red : const Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_rounded,
                        color:
                            _isListening ? Colors.red : const Color(0xFF64748B),
                        size: 22,
                      ),
                      onPressed: isBlocked ? null : _toggleListening,
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isLoading
                      ? [Colors.red.shade400, Colors.red.shade700]
                      : (isBlocked
                          ? [Colors.grey.shade400, Colors.grey.shade500]
                          : [accentBlue, primaryNavy]),
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _isLoading ? Icons.stop_rounded : Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: _isLoading
                    ? _stopGenerating
                    : (_cooldownManager.isInCooldown ? null : _sendMessage),
                splashRadius: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: _isSelectionMode
            ? Text('${_selectedIndices.length} selected',
                style: const TextStyle(
                    color: primaryNavy,
                    fontWeight: FontWeight.bold,
                    fontSize: 17))
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FYBTT AI Assistant',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Online Support',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red),
                  onPressed: _deleteSelectedMessages,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.black87),
                  onPressed: _clearSelection,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined,
                      color: Color(0xFF64748B)),
                  onPressed: _messages.isNotEmpty ? _clearAllMessages : null,
                ),
              ],
      ),
      body: Column(
        children: [
          _buildCooldownBanner(),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isSelected = _selectedIndices.contains(index);
                      final isSpeaking = _currentlySpeakingIndex == index;
                      final isLastAiMessage = !message.isUser &&
                          index == _messages.length - 1 &&
                          _isLoading;

                      return GestureDetector(
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            setState(() => _isSelectionMode = true);
                          }
                          _toggleSelection(index);
                        },
                        onTap: () {
                          if (_isSelectionMode) _toggleSelection(index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accentBlue.withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(color: accentBlue, width: 1.5)
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
                                  activeColor: accentBlue,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4)),
                                ),
                              ],
                              if (!message.isUser) ...[
                                _buildAvatar(isAi: true),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: message.isUser
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.76,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: message.isUser
                                            ? userBubbleColor
                                            : Colors.white,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(18),
                                          topRight: const Radius.circular(18),
                                          bottomLeft: Radius.circular(
                                              message.isUser ? 18 : 4),
                                          bottomRight: Radius.circular(
                                              message.isUser ? 4 : 18),
                                        ),
                                        border: message.isUser
                                            ? null
                                            : Border.all(
                                                color: const Color(0xFFE2E8F0),
                                                width: 1),
                                      ),
                                      child: message.isUser
                                          ? Text(
                                              message.text,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                height: 1.4,
                                              ),
                                            )
                                          : MarkdownBody(
                                              data: isLastAiMessage
                                                  ? '${message.text} ▍'
                                                  : message.text,
                                              selectable: true,
                                              onTapLink: (text, href, title) =>
                                                  _handleLinkTap(href, text),
                                              styleSheet:
                                                  MarkdownStyleSheet(
                                                p: const TextStyle(
                                                  color: Color(0xFF1E293B),
                                                  fontSize: 14.5,
                                                  height: 1.5,
                                                ),
                                                a: const TextStyle(
                                                  color: Color(0xFF2563EB),
                                                  decoration:
                                                      TextDecoration.underline,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                h1: const TextStyle(
                                                    color: primaryNavy,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18),
                                                h2: const TextStyle(
                                                    color: primaryNavy,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                                h3: const TextStyle(
                                                    color: primaryNavy,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15),
                                              ),
                                            ),
                                    ),
                                    if (!message.isUser &&
                                        message.text.isNotEmpty &&
                                        !isLastAiMessage) ...[
                                      const SizedBox(height: 6),
                                      _buildInteractionBar(
                                          index, message, isSpeaking),
                                    ],
                                  ],
                                ),
                              ),
                              if (message.isUser) ...[
                                const SizedBox(width: 8),
                                _buildAvatar(isAi: false),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
_buildPulsingFallbackIndicator(),
          if (_isLoading && !_isFallbackActive && (_messages.isEmpty || _messages.last.text.isEmpty))
            const _ModernThinkingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }
}

class _ModernThinkingIndicator extends StatefulWidget {
  const _ModernThinkingIndicator();

  @override
  State<_ModernThinkingIndicator> createState() =>
      _ModernThinkingIndicatorState();
}

class _ModernThinkingIndicatorState extends State<_ModernThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _currentStepIndex = 0;
  Timer? _stepTimer;

  final List<String> _thinkingSteps = [
    "Analyzing your query...",
    "Retrieving FYBTT data...",
    "Formulating response...",
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _stepTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          _currentStepIndex =
              (_currentStepIndex + 1) % _thinkingSteps.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _animController,
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Text(
                    _thinkingSteps[_currentStepIndex],
                    key: ValueKey<int>(_currentStepIndex),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}