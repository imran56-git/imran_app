import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../widgets/success_toast.dart';

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

  static const List<String> _quickEmojis = ['❤️', '👍', '😂', '😮', '😢', '🙏'];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudioListeners();
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

  bool _canEditMessage() {
    if (!widget.isMe) return false;
    if (widget.message.type.toLowerCase() != 'text') return false;
    if (widget.message.isDeletedForEveryone) return false;
    if (widget.message.timestamp == null) return false;

    final messageTime = widget.message.timestamp!;
    final currentTime = DateTime.now();
    final difference = currentTime.difference(messageTime);

    return difference.inMinutes < 15;
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

  void _showEditDialog(BuildContext context) {
    final TextEditingController editController =
        TextEditingController(text: widget.message.content);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Edit Message',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: editController,
            maxLines: null,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Edit your message...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E4C7A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final newText = editController.text.trim();
                if (newText.isNotEmpty && newText != widget.message.content) {
                  Navigator.pop(dialogContext);
                  try {
                    await _chatService.editMessage(
                      widget.chatRoomId,
                      widget.message.messageId,
                      newText,
                    );
                    if (context.mounted) {
                      SuccessToast.show(context, "Message edited");
                    }
                  } catch (e) {
                    debugPrint('Error editing message: $e');
                  }
                } else {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showForwardDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Forward Message To Group",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('groups')
                      .where('members', arrayContains: widget.currentUserId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text("No active groups available to forward."),
                      );
                    }

                    final docs = snapshot.data!.docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['isDismissed'] != true;
                    }).toList();

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final String gName =
                            (data['name'] ?? data['groupName'] ?? 'Group')
                                .toString();

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE3F2FD),
                            child:
                                Icon(Icons.groups, color: Color(0xFF1E4C7A)),
                          ),
                          title: Text(gName),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E4C7A),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              try {
                                await _chatService.forwardMessage(
                                  targetChatId: doc.id,
                                  senderId: widget.currentUserId,
                                  receiverId: 'group',
                                  message: widget.message.content,
                                  type: widget.message.type,
                                  mediaMetaData: widget.message.mediaMetaData,
                                );
                                if (context.mounted) {
                                  SuccessToast.show(
                                      context, "Message forwarded to $gName");
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Forward error: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text(
                              "Send",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportMessageDialog(BuildContext context) {
    final List<String> reasons = [
      'Spam or unwanted content',
      'Harassment or abusive language',
      'Inappropriate media or link',
      'Off-topic disturbance in batch',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Report Message",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((reason) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                title: Text(reason, style: const TextStyle(fontSize: 13.5)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _chatService.reportAbuseOrSpam(
                    reporterId: widget.currentUserId,
                    targetId: widget.message.senderId,
                    targetType: 'message',
                    reason: reason,
                    chatOrGroupId: widget.chatRoomId,
                    messageId: widget.message.messageId,
                  );
                  if (context.mounted) {
                    SuccessToast.show(context, "Report submitted for review");
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _showReactionsSummarySheet() {
    final reactions = widget.message.reactions;
    if (reactions.isEmpty) return;

    final Map<String, int> emojiCounts = {};
    for (final emoji in reactions.values) {
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
                const SizedBox(height: 8),
                const Text(
                  "Individual student identities in reactions are kept private.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon() {
    if (!widget.isMe) return const SizedBox.shrink();
    final status = widget.message.status.toLowerCase();
    final bool isSeenByOthers =
        widget.message.readBy.where((id) => id != widget.currentUserId).isNotEmpty;
    final bool isDeliveredToOthers = widget.message.deliveredTo
        .where((id) => id != widget.currentUserId)
        .isNotEmpty;

    if (status == 'seen' || status == 'read' || isSeenByOthers) {
      return const Icon(Icons.done_all, size: 16, color: Color(0xFF34B7F1));
    }
    if (status == 'delivered' || isDeliveredToOthers) {
      return const Icon(Icons.done_all, size: 16, color: Colors.grey);
    }
    return const Icon(Icons.done, size: 14, color: Colors.grey);
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
              backgroundColor: const Color(0xFF1E4C7A),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
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
                  color: const Color(0xFF1E4C7A),
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
                color: const Color(0xFF1E4C7A).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "${_playbackSpeed == 1.0 ? '1x' : _playbackSpeed == 1.5 ? '1.5x' : '2x'}",
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E4C7A),
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
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: const Color(0xFF1E4C7A),
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
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blueAccent,
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
              color: Color(0xFF1E4C7A),
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
            color: Colors.black87,
            height: 1.32,
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
      counts[emoji] = (counts[emoji] ?? 0) + 1;
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

  void _showLongPressMenu(BuildContext context) {
    final bool isStarred =
        widget.message.starredBy.contains(widget.currentUserId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.message.isDeletedForEveryone)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _quickEmojis.map((emoji) {
                      final bool isMyReaction =
                          widget.message.reactions[widget.currentUserId] ==
                              emoji;
                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          await _chatService.reactMessage(
                            widget.chatRoomId,
                            widget.message.messageId,
                            widget.currentUserId,
                            isMyReaction ? '' : emoji,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isMyReaction
                                ? Colors.blue.shade50
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const Divider(height: 1),
              if (widget.message.type == 'text' &&
                  !widget.message.isDeletedForEveryone)
                ListWhiteTiles(
                  leading: const Icon(Icons.copy_rounded, color: Colors.black87),
                  title: const Text('Copy Text'),
                  onTap: () async {
                    await Clipboard.setData(
                        ClipboardData(text: widget.message.content));
                    if (context.mounted) {
                      Navigator.pop(sheetCtx);
                      SuccessToast.show(context, "Copied to Clipboard");
                    }
                  },
                ),
              if (!widget.message.isDeletedForEveryone)
                ListWhiteTiles(
                  leading:
                      const Icon(Icons.reply_rounded, color: Colors.black87),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    widget.onReplyPressed(widget.message);
                  },
                ),
              if (!widget.message.isDeletedForEveryone)
                ListWhiteTiles(
                  leading:
                      const Icon(Icons.forward_rounded, color: Colors.black87),
                  title: const Text('Forward Message'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showForwardDialog(context);
                  },
                ),
              if (!widget.message.isDeletedForEveryone)
                ListWhiteTiles(
                  leading: Icon(
                    isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber.shade700,
                  ),
                  title: Text(isStarred ? 'Unstar Message' : 'Star Message'),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _chatService.toggleStarMessage(
                      chatId: widget.chatRoomId,
                      messageId: widget.message.messageId,
                      userId: widget.currentUserId,
                      star: !isStarred,
                    );
                  },
                ),
              if (_canEditMessage())
                ListWhiteTiles(
                  leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                  title: const Text(
                    'Edit',
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showEditDialog(context);
                  },
                ),
              ListWhiteTiles(
                leading:
                    const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Delete for Me',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _chatService.deleteMessageForMe(
                    widget.chatRoomId,
                    widget.message.messageId,
                    widget.currentUserId,
                  );
                },
              ),
              if (widget.isMe && !widget.message.isDeletedForEveryone)
                ListWhiteTiles(
                  leading: const Icon(Icons.delete_forever_rounded,
                      color: Colors.red),
                  title: const Text(
                    'Delete for Everyone',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _chatService.deleteMessageForEveryone(
                      widget.chatRoomId,
                      widget.message.messageId,
                    );
                  },
                ),
              if (!widget.isMe && !widget.message.isDeletedForEveryone)
                ListWhiteTiles(
                  leading: const Icon(Icons.flag_outlined,
                      color: Colors.deepOrange),
                  title: const Text(
                    'Report Message',
                    style: TextStyle(color: Colors.deepOrange),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showReportMessageDialog(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.deletedForUsers.contains(widget.currentUserId)) {
      return const SizedBox.shrink();
    }

    final bubbleColor = widget.isMe ? const Color(0xFFE3F2FD) : Colors.white;
    final msgType = widget.message.type.toLowerCase();
    final bool isStarred =
        widget.message.starredBy.contains(widget.currentUserId);

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showLongPressMenu(context),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
              bottomRight: Radius.circular(widget.isMe ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              )
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
                if (widget.message.replyToMessageId != null)
                  GestureDetector(
                    onTap: widget.onReplyPreviewTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(
                          left: BorderSide(color: Color(0xFF1E4C7A), width: 3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.reply,
                              size: 12, color: Color(0xFF1E4C7A)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.message.replyText ??
                                  "Replied to a message",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                      color: Color(0xFF1E4C7A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  Text(
                    _formatTime(widget.message.timestamp),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 4),
                  if (widget.isMe) _buildStatusIcon(),
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
