import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final String chatRoomId;
  final String currentUserId;
  final Function(MessageModel) onReplyPressed;
  final VoidCallback? onReplyPreviewTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.chatRoomId,
    required this.currentUserId,
    required this.onReplyPressed,
    this.onReplyPreviewTap,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  late final AudioPlayer _audioPlayer;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;

  final ChatService _chatService = ChatService();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;

  String? _fetchedOriginalReplyText;
  bool _isLoadingReplyText = false;

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _outgoingBg = Color(0xFFEFF6FF);
  static const Color _seenElectricCyan = Color(0xFF06B6D4);

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudioListeners();
    _resolveOriginalReplyMessageIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.replyToMessageId !=
            widget.message.replyToMessageId ||
        oldWidget.message.replyText != widget.message.replyText) {
      _resolveOriginalReplyMessageIfNeeded();
    }
  }

  Future<void> _resolveOriginalReplyMessageIfNeeded() async {
    final String? replyId = widget.message.replyToMessageId;
    if (replyId == null || replyId.trim().isEmpty) return;

    if (widget.message.replyText != null &&
        widget.message.replyText!.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _fetchedOriginalReplyText = widget.message.replyText!.trim();
        });
      }
      return;
    }

    if (_isLoadingReplyText) return;
    _isLoadingReplyText = true;

    try {
      DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('chats')
          .doc(widget.chatRoomId)
          .collection('messages')
          .doc(replyId)
          .get();

      if (!doc.exists) {
        doc = await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.chatRoomId)
            .collection('messages')
            .doc(replyId)
            .get();
      }

      if (doc.exists && doc.data() != null && mounted) {
        final data = doc.data()!;
        final String type = (data['type'] ?? 'text').toString().toLowerCase();
        final String rawContent =
            (data['content'] ?? data['message'] ?? '').toString();

        String resolved = rawContent;
        if (type == 'image') resolved = '📷 Photo';
        if (type == 'video') resolved = '🎥 Video';
        if (type == 'audio' || type == 'voice') resolved = '🎵 Voice message';
        if (type == 'document' || type == 'file') {
          final meta = data['mediaMetaData'] as Map<dynamic, dynamic>?;
          resolved = '📄 ${meta?['fileName'] ?? 'Document'}';
        }
        if (type == 'location') resolved = '📍 Shared Location';

        setState(() {
          _fetchedOriginalReplyText =
              resolved.isNotEmpty ? resolved : 'Attachment';
        });
      }
    } catch (_) {
    } finally {
      _isLoadingReplyText = false;
    }
  }

  void _initAudioListeners() {
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    _playerStateSubscription =
        _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  String? _extractFirstUrl(String text) {
    final RegExp urlRegExp = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    final match = urlRegExp.firstMatch(text);
    return match?.group(0);
  }

  Future<void> _cyclePlaybackSpeed() async {
    double nextSpeed = 1.0;
    if (_playbackSpeed == 1.0) {
      nextSpeed = 1.5;
    } else if (_playbackSpeed == 1.5) {
      nextSpeed = 2.0;
    } else {
      nextSpeed = 1.0;
    }

    setState(() => _playbackSpeed = nextSpeed);
    try {
      await _audioPlayer.setPlaybackRate(nextSpeed);
    } catch (e) {
      debugPrint('Playback speed error: $e');
    }
  }

  Future<void> _toggleAudio() async {
    if (widget.message.content.trim().isEmpty) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
        await _audioPlayer.play(UrlSource(widget.message.content));
      }
    } catch (e) {
      debugPrint('Audio play error: $e');
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  void _showInAppImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_rounded,
                          color: Colors.white),
                      tooltip: 'Download / Open Externally',
                      onPressed: () => _openUrl(imageUrl),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReactionsSummarySheet() {
    final reactions = widget.message.reactions;
    if (reactions.isEmpty) return;

    final Map<String, int> emojiCounts = {};
    for (final emoji in reactions.values) {
      if (emoji.trim().isEmpty) continue;
      emojiCounts[emoji] = (emojiCounts[emoji] ?? 0) + 1;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Message Reactions (${reactions.length})",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: emojiCounts.entries.map((entry) {
                    return Chip(
                      backgroundColor: Colors.blue.shade50,
                      label: Text(
                        "${entry.key}  ${entry.value}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOriginalReplyBox() {
    final bool hasReplyId = widget.message.replyToMessageId != null &&
        widget.message.replyToMessageId!.trim().isNotEmpty;
    final bool hasReplyText = widget.message.replyText != null &&
        widget.message.replyText!.trim().isNotEmpty;

    if (!hasReplyId && !hasReplyText) {
      return const SizedBox.shrink();
    }

    final String displayReplyText = hasReplyText
        ? widget.message.replyText!.trim()
        : (_fetchedOriginalReplyText ?? 'Loading original message...');

    return GestureDetector(
      onTap: widget.onReplyPreviewTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: widget.isMe
              ? _brandBlue.withOpacity(0.08)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: const Border(
            left: BorderSide(color: _brandBlue, width: 3.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reply_rounded, size: 13, color: _brandBlue),
                SizedBox(width: 4),
                Text(
                  "Replied message",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: _brandBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              displayReplyText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (!widget.isMe) return const SizedBox.shrink();
    final status = widget.message.status.toLowerCase();
    final bool isSeenByOthers = widget.message.readBy
        .where((id) => id != widget.currentUserId)
        .isNotEmpty;
    final bool isDeliveredToOthers = widget.message.deliveredTo
        .where((id) => id != widget.currentUserId)
        .isNotEmpty;

    Widget iconWidget;

    if (status == 'seen' || status == 'read' || isSeenByOthers) {
      iconWidget = Container(
        key: const ValueKey('seen_status'),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: _seenElectricCyan.withOpacity(0.16),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all_rounded, size: 13, color: _seenElectricCyan),
          ],
        ),
      );
    } else if (status == 'delivered' || isDeliveredToOthers) {
      iconWidget = const Icon(
        Icons.done_all_rounded,
        key: ValueKey('delivered_status'),
        size: 14,
        color: Color(0xFF94A3B8),
      );
    } else {
      iconWidget = const Icon(
        Icons.done_rounded,
        key: ValueKey('sent_status'),
        size: 13,
        color: Color(0xFF94A3B8),
      );
    }

    return SizedBox(
      width: 22,
      height: 14,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: iconWidget,
        ),
      ),
    );
  }

  Widget _buildAudioBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggleAudio,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: _brandBlue,
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 115,
                child: LinearProgressIndicator(
                  value: _duration.inMilliseconds > 0
                      ? (_position.inMilliseconds / _duration.inMilliseconds)
                          .clamp(0.0, 1.0)
                      : 0.0,
                  backgroundColor: Colors.grey.shade300,
                  color: _brandBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isPlaying || _position.inSeconds > 0
                    ? "${_position.inSeconds}s / ${_duration.inSeconds}s"
                    : "Voice Message",
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _cyclePlaybackSpeed,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _brandBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${_playbackSpeed == 1.0 ? '1x' : _playbackSpeed == 1.5 ? '1.5x' : '2x'}",
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: _brandBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageBubble() {
    return GestureDetector(
      onTap: () => _showInAppImagePreview(widget.message.content),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          widget.message.content,
          width: 220,
          height: 200,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 220,
              height: 200,
              color: Colors.grey.shade200,
              child: const Center(
                child: CircularProgressIndicator(
                  color: _brandBlue,
                  strokeWidth: 2.5,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            width: 220,
            height: 200,
            color: Colors.grey.shade200,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
                SizedBox(height: 4),
                Text(
                  "Failed to load image",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoBubble() {
    return InkWell(
      onTap: () => _openUrl(widget.message.content),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _primaryNavy,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _accentBlue,
              child: Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 24),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Video Attachment",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Tap to play video",
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentBubble() {
    final fileName =
        widget.message.mediaMetaData?['fileName'] ?? "Study Document / PDF";
    return InkWell(
      onTap: () => _openUrl(widget.message.content),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_rounded,
                color: Colors.redAccent, size: 32),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Tap to view / download",
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.download_for_offline_rounded,
              color: _brandBlue,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBubble() {
    return InkWell(
      onTap: () => _openUrl(
          "https://www.google.com/maps/search/?api=1&query=${widget.message.content}"),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_rounded,
                color: Colors.redAccent, size: 32),
            const SizedBox(width: 10),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Shared Location",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Tap to open in Map",
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.open_in_new_rounded,
                color: Colors.grey.shade600, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTextWithLinkPreview() {
    final String content = widget.message.content;
    final String? detectedUrl = _extractFirstUrl(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (detectedUrl != null)
          InkWell(
            onTap: () => _openUrl(detectedUrl),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_rounded,
                      color: Colors.blueAccent, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      detectedUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blueAccent,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14.5,
            color: Color(0xFF0F172A),
            height: 1.34,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildReactionsRow() {
    if (widget.message.reactions.isEmpty) return const SizedBox.shrink();

    final Map<String, int> counts = {};
    for (final emoji in widget.message.reactions.values) {
      if (emoji.trim().isEmpty) continue;
      counts[emoji] = (emojiCounts[emoji] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onTap: _showReactionsSummarySheet,
        child: Wrap(
          spacing: 4,
          children: counts.entries.map((entry) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                "${entry.key} ${entry.value > 1 ? entry.value : ''}".trim(),
                style: const TextStyle(fontSize: 11),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.deletedForUsers.contains(widget.currentUserId)) {
      return const SizedBox.shrink();
    }

    final bubbleColor = widget.isMe ? _outgoingBg : Colors.white;
    final msgType = widget.message.type.toLowerCase();
    final bool isStarred =
        widget.message.starredBy.contains(widget.currentUserId);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 220),
      tween: Tween<double>(begin: 0.94, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
        );
      },
      child: Align(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
              bottomRight: Radius.circular(widget.isMe ? 4 : 18),
            ),
            border: Border.all(
              color: widget.isMe
                  ? const Color(0xFFBFDBFE).withOpacity(0.6)
                  : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryNavy.withOpacity(widget.isMe ? 0.04 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.message.isDeletedForEveryone)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      "This message was deleted",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                )
              else ...[
                if (widget.message.isForwarded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.forward_rounded,
                            size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 3),
                        Text(
                          "Forwarded",
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                _buildOriginalReplyBox(),
                if (msgType == 'audio' || msgType == 'voice')
                  _buildAudioBubble()
                else if (msgType == 'image')
                  _buildImageBubble()
                else if (msgType == 'video')
                  _buildVideoBubble()
                else if (msgType == 'document' || msgType == 'file')
                  _buildDocumentBubble()
                else if (msgType == 'location')
                  _buildLocationBubble()
                else
                  _buildTextWithLinkPreview(),
              ],
              _buildReactionsRow(),
              if (widget.message.replyThreadCount > 0 &&
                  !widget.message.isDeletedForEveryone)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "${widget.message.replyThreadCount} repl${widget.message.replyThreadCount == 1 ? 'y' : 'ies'}",
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: _brandBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  if (widget.message.isPinned &&
                      !widget.message.isDeletedForEveryone) ...[
                    const Icon(Icons.push_pin_rounded,
                        size: 11, color: Colors.amber),
                    const SizedBox(width: 3),
                  ],
                  if (isStarred && !widget.message.isDeletedForEveryone) ...[
                    Icon(Icons.star_rounded,
                        size: 12, color: Colors.amber.shade700),
                    const SizedBox(width: 3),
                  ],
                  if (widget.message.isEdited == true &&
                      !widget.message.isDeletedForEveryone) ...[
                    Text(
                      "edited ",
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  Text(
                    _formatTime(widget.message.timestamp),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                  if (widget.isMe) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ListWhiteTiles extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final VoidCallback onTap;

  const ListWhiteTiles({
    super.key,
    required this.leading,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: title,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
