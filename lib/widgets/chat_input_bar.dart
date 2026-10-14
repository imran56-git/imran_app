import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';

class ChatInputBar extends StatefulWidget {
  final String chatRoomId;
  final String senderId;
  final String receiverId;
  final Function(bool) onTypingChanged;
  final String? replyToMessageId;
  final String? replyToText;
  final VoidCallback? onCancelReply;
  final bool isMutedByTeacher;
  final String? disabledReasonText;
  final String initialMessageCategory;

  const ChatInputBar({
    super.key,
    required this.chatRoomId,
    required this.senderId,
    required this.receiverId,
    required this.onTypingChanged,
    this.replyToMessageId,
    this.replyToText,
    this.onCancelReply,
    this.isMutedByTeacher = false,
    this.disabledReasonText,
    this.initialMessageCategory = 'general',
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isTyping = false;
  bool _isUploading = false;
  bool _showEmojiPanel = false;
  bool _isRecordingVoice = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  String _attachmentCategory = 'general';
  String? _failedMessageText;
  String? _failedReplyId;
  String? _failedReplyText;

  static const List<String> _commonEmojis = [
    '😀', '😂', '😊', '😍', '🤔', '😎', '😢', '😭',
    '👍', '👎', '👏', '🙏', '🔥', '🎉', '❤️', '💯',
    '📚', '✏️', '📝', '🎓', '✅', '❌', '⭐', '💡',
    '📌', '📢', '🏆', '🤝', '🙋‍♂️', '🙋‍♀️', '⏰', '🚀',
  ];

  static const List<Map<String, String>> _quickStickers = [
    {'emoji': '📚✨', 'label': 'Study Hard!'},
    {'emoji': '✅👍', 'label': 'Well Done!'},
    {'emoji': '❓🙋', 'label': 'I have a doubt'},
    {'emoji': '📝⏰', 'label': 'Homework Due'},
    {'emoji': '🎯🏆', 'label': ' Keep Going!'},
    {'emoji': '🙏📘', 'label': 'Thank You Sir'},
  ];

  @override
  void initState() {
    super.initState();
    _attachmentCategory = widget.initialMessageCategory;
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPanel && mounted) {
        setState(() => _showEmojiPanel = false);
      }
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    if (_isTyping) {
      _chatService.updateTypingStatus(
          widget.chatRoomId, widget.senderId, false);
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final bool typing = _controller.text.trim().isNotEmpty;
    if (_isTyping != typing) {
      if (mounted) {
        setState(() => _isTyping = typing);
      }
      widget.onTypingChanged(_isTyping);
      _chatService.updateTypingStatus(
          widget.chatRoomId, widget.senderId, _isTyping);
    }
  }

  void _toggleEmojiPanel() {
    if (_isUploading || widget.isMutedByTeacher) return;
    if (_showEmojiPanel) {
      setState(() => _showEmojiPanel = false);
      _focusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _showEmojiPanel = true);
    }
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final int start = selection.start >= 0 ? selection.start : text.length;
    final int end = selection.end >= 0 ? selection.end : text.length;
    final String newText = text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _sendQuickSticker(String stickerText) async {
    if (_isUploading || widget.isMutedByTeacher) return;
    setState(() => _showEmojiPanel = false);
    try {
      await _chatService.sendMessage(
        chatId: widget.chatRoomId,
        senderId: widget.senderId,
        receiverId: widget.receiverId,
        message: stickerText,
        type: 'text',
        replyToMessageId: widget.replyToMessageId,
        replyToText: widget.replyToText,
        clientMessageId:
            '${widget.senderId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (widget.onCancelReply != null) {
        widget.onCancelReply!();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send sticker: $e')),
        );
      }
    }
  }

  void _showAttachmentBottomSheet() {
    if (_isUploading || widget.isMutedByTeacher) return;

    final bool isGroupChat = widget.receiverId == 'group';
    final List<Map<String, String>> groupCategories = [
      {'key': 'general', 'label': 'General'},
      {'key': 'study_material', 'label': 'Study Material'},
      {'key': 'homework', 'label': 'Homework'},
      {'key': 'assignment', 'label': 'Assignment'},
      {'key': 'announcement', 'label': 'Announcement'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E4C7A),
                    ),
                  ),
                  if (isGroupChat) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: groupCategories.map((cat) {
                          final bool isSel =
                              _attachmentCategory == cat['key'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                cat['label']!,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              selected: isSel,
                              selectedColor:
                                  const Color(0xFF1E4C7A).withOpacity(0.15),
                              labelStyle: TextStyle(
                                color: isSel
                                    ? const Color(0xFF1E4C7A)
                                    : Colors.black87,
                                fontWeight:
                                    isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (_) {
                                setSheetState(() {
                                  _attachmentCategory = cat['key']!;
                                });
                                setState(() {
                                  _attachmentCategory = cat['key']!;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _attachmentTile(Icons.photo_library_rounded, "Gallery",
                          Colors.purple, 'gallery'),
                      _attachmentTile(Icons.camera_alt_rounded, "Camera",
                          Colors.pink, 'camera'),
                      _attachmentTile(Icons.description_rounded,
                          "PDF / Document", Colors.blue, 'document'),
                      _attachmentTile(Icons.audiotrack_rounded, "Audio File",
                          Colors.orange, 'audio'),
                      _attachmentTile(Icons.video_library_rounded, "Video",
                          Colors.red, 'video'),
                      _attachmentTile(Icons.location_on_rounded, "Location",
                          Colors.teal, 'location'),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _attachmentTile(
      IconData icon, String label, Color color, String type) {
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
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAttachmentPick(String type) async {
    if (mounted) setState(() => _isUploading = true);
    try {
      if (type == 'gallery') {
        final XFile? image = await _imagePicker.pickImage(
            source: ImageSource.gallery, imageQuality: 80);
        if (image != null) {
          await _chatService.sendImageFile(
            chatRoomId: widget.chatRoomId,
            senderId: widget.senderId,
            receiverId: widget.receiverId,
            file: File(image.path),
            messageCategory: _attachmentCategory,
          );
        }
      } else if (type == 'camera') {
        final XFile? image = await _imagePicker.pickImage(
            source: ImageSource.camera, imageQuality: 80);
        if (image != null) {
          await _chatService.sendImageFile(
            chatRoomId: widget.chatRoomId,
            senderId: widget.senderId,
            receiverId: widget.receiverId,
            file: File(image.path),
            messageCategory: _attachmentCategory,
          );
        }
      } else if (type == 'video') {
        final XFile? video =
            await _imagePicker.pickVideo(source: ImageSource.gallery);
        if (video != null) {
          await _chatService.sendVideoFile(
            chatRoomId: widget.chatRoomId,
            senderId: widget.senderId,
            receiverId: widget.receiverId,
            file: File(video.path),
            messageCategory: _attachmentCategory,
          );
        }
      } else if (type == 'document') {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'pdf',
            'doc',
            'docx',
            'ppt',
            'pptx',
            'xls',
            'xlsx',
            'txt',
            'zip'
          ],
        );
        if (result != null && result.files.single.path != null) {
          await _chatService.sendDocumentFile(
            chatRoomId: widget.chatRoomId,
            senderId: widget.senderId,
            receiverId: widget.receiverId,
            file: File(result.files.single.path!),
            fileName: result.files.single.name,
            messageCategory: _attachmentCategory,
          );
        }
      } else if (type == 'audio') {
        final FilePickerResult? result =
            await FilePicker.platform.pickFiles(type: FileType.audio);
        if (result != null && result.files.single.path != null) {
          await _chatService.sendAudioFile(
            chatRoomId: widget.chatRoomId,
            senderId: widget.senderId,
            receiverId: widget.receiverId,
            file: File(result.files.single.path!),
          );
        }
      } else if (type == 'location') {
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

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isUploading || widget.isMutedByTeacher) return;

    final String? currentReplyId = widget.replyToMessageId;
    final String? currentReplyText = widget.replyToText;
    final String clientMsgId =
        '${widget.senderId}_${DateTime.now().millisecondsSinceEpoch}';

    _controller.clear();
    if (mounted) {
      setState(() {
        _isTyping = false;
        _failedMessageText = null;
      });
    }
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
        replyToText: currentReplyText,
        messageCategory: widget.initialMessageCategory,
        clientMessageId: clientMsgId,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _failedMessageText = text;
          _failedReplyId = currentReplyId;
          _failedReplyText = currentReplyText;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error. Tap Retry to resend: $e')),
        );
      }
    }
  }

  Future<void> _retryFailedMessage() async {
    final String? textToRetry = _failedMessageText;
    if (textToRetry == null || textToRetry.isEmpty || _isUploading) return;

    setState(() => _failedMessageText = null);
    try {
      await _chatService.sendMessage(
        chatId: widget.chatRoomId,
        senderId: widget.senderId,
        receiverId: widget.receiverId,
        message: textToRetry,
        type: 'text',
        replyToMessageId: _failedReplyId,
        replyToText: _failedReplyText,
        messageCategory: widget.initialMessageCategory,
        clientMessageId:
            '${widget.senderId}_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _failedMessageText = textToRetry);
      }
    }
  }

  void _startVoiceNoteSession() {
    if (_isUploading || widget.isMutedByTeacher) return;
    _recordingTimer?.cancel();
    setState(() {
      _isRecordingVoice = true;
      _recordingSeconds = 0;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingSeconds++);
      }
    });
  }

  void _cancelVoiceNoteSession() {
    _recordingTimer?.cancel();
    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
    });
  }

  Future<void> _finishAndPickVoiceNote() async {
    _recordingTimer?.cancel();
    setState(() {
      _isRecordingVoice = false;
      _recordingSeconds = 0;
    });
    await _handleAttachmentPick('audio');
  }

  String _formatDuration(int totalSeconds) {
    final int mins = totalSeconds ~/ 60;
    final int secs = totalSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildEmojiAndStickerPanel() {
    if (!_showEmojiPanel) return const SizedBox.shrink();

    return Container(
      height: 230,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickStickers.length,
              itemBuilder: (context, index) {
                final item = _quickStickers[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: Colors.blue.shade50,
                    label: Text(
                      "${item['emoji']} ${item['label']}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E4C7A),
                      ),
                    ),
                    onPressed: () => _sendQuickSticker(
                        "${item['emoji']} ${item['label']}"),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              itemCount: _commonEmojis.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemBuilder: (context, index) {
                final emoji = _commonEmojis[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _insertEmoji(emoji),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMutedByTeacher) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  enabled: false,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: widget.disabledReasonText ?? "Muted by teacher",
                    hintStyle: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.mic_off_rounded,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.red.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.red.shade200),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade300,
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isUploading)
          const LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E4C7A)),
          ),
        if (_failedMessageText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.red.shade50,
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Failed to send: $_failedMessageText",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _retryFailedMessage,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text("Retry"),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                  onPressed: () => setState(() => _failedMessageText = null),
                ),
              ],
            ),
          ),
        if (widget.replyToMessageId != null && widget.replyToText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                left: BorderSide(color: Color(0xFF1E4C7A), width: 4),
              ),
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
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.87),
                          fontSize: 13,
                        ),
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
          child: _isRecordingVoice
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record_rounded,
                          color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "Voice Note  ${_formatDuration(_recordingSeconds)}",
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _cancelVoiceNoteSession,
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E4C7A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: _finishAndPickVoiceNote,
                        icon: const Icon(Icons.upload_file_rounded,
                            color: Colors.white, size: 16),
                        label: const Text(
                          "Attach Audio",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : Row(
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
                              icon: Icon(
                                _showEmojiPanel
                                    ? Icons.keyboard_alt_outlined
                                    : Icons.emoji_emotions_outlined,
                                color: _showEmojiPanel
                                    ? const Color(0xFF1E4C7A)
                                    : Colors.grey,
                              ),
                              onPressed: _toggleEmojiPanel,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                minLines: 1,
                                maxLines: 5,
                                enabled: !_isUploading,
                                decoration: const InputDecoration(
                                  hintText: 'Type a message...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 10.0,
                                    horizontal: 4,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.attach_file_rounded,
                                  color: Colors.grey),
                              onPressed: _isUploading
                                  ? null
                                  : _showAttachmentBottomSheet,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    GestureDetector(
                      onTap:
                          _isTyping ? _handleSend : _startVoiceNoteSession,
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
        _buildEmojiAndStickerPanel(),
      ],
    );
  }
}
