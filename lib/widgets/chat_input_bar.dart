import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/media_preview_editor_screen.dart';
import '../services/chat_service.dart';
import 'media_shortcut_tray.dart';

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

  final List<TrayMediaItem> _trayItems = [];
  final Set<String> _selectedTrayIds = {};

  String _attachmentCategory = 'general';
  String? _failedMessageText;
  String? _failedReplyId;
  String? _failedReplyText;

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);

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
    {'emoji': '🎯🏆', 'label': 'Keep Going!'},
    {'emoji': '🙏📘', 'label': 'Thank You Sir'},
  ];

  String get _effectiveChatRoomId {
    final direct = widget.chatRoomId.trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    return '${widget.receiverId}_${widget.senderId}';
  }

  bool get _canSend =>
      _isTyping || _trayItems.isNotEmpty || _controller.text.trim().isNotEmpty;

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
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMessageCategory != widget.initialMessageCategory) {
      _attachmentCategory = widget.initialMessageCategory;
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    if (_isTyping) {
      _chatService.updateTypingStatus(
          _effectiveChatRoomId, widget.senderId, false);
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
          _effectiveChatRoomId, widget.senderId, _isTyping);
    }
  }

  void _toggleEmojiPanel() {
    if (_isUploading || widget.isMutedByTeacher) return;
    HapticFeedback.lightImpact();
    if (_showEmojiPanel) {
      setState(() => _showEmojiPanel = false);
      _focusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _showEmojiPanel = true);
    }
  }

  void _insertEmoji(String emoji) {
    HapticFeedback.selectionClick();
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
    HapticFeedback.lightImpact();
    setState(() => _showEmojiPanel = false);
    try {
      await _chatService.sendMessage(
        chatId: _effectiveChatRoomId,
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
    HapticFeedback.mediumImpact();

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
                boxShadow: [
                  BoxShadow(
                    color: _primaryNavy.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Send Attachment",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _brandBlue,
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
                                  _brandBlue.withOpacity(0.15),
                              labelStyle: TextStyle(
                                color: isSel
                                    ? _brandBlue
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
    try {
      if (type == 'gallery') {
        final List<XFile> images =
            await _imagePicker.pickMultiImage(imageQuality: 80);
        if (images.isEmpty) return;

        if (images.length == 1) {
          final singleFile = File(images.first.path);
          if (!mounted) return;
          final MediaEditorResult? result =
              await Navigator.push<MediaEditorResult>(
            context,
            MaterialPageRoute(
              builder: (_) => MediaPreviewEditorScreen(file: singleFile),
            ),
          );
          if (result != null) {
            await _sendSingleProcessedMedia(
              file: result.file,
              isImage: true,
              caption: result.caption,
            );
          }
        } else {
          final List<File> files = images.map((x) => File(x.path)).toList();
          if (!mounted) return;
          final MediaEditorResult? result =
              await Navigator.push<MediaEditorResult>(
            context,
            MaterialPageRoute(
              builder: (_) => MediaPreviewEditorScreen(
                file: files.first,
                isAlbum: true,
                albumCount: files.length,
              ),
            ),
          );
          if (result != null) {
            if (mounted) setState(() => _isUploading = true);
            await _chatService.sendMediaAlbum(
              chatRoomId: _effectiveChatRoomId,
              senderId: widget.senderId,
              receiverId: widget.receiverId,
              files: files,
              caption: result.caption,
              messageCategory: _attachmentCategory,
            );
          }
        }
      } else if (type == 'camera') {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
        );
        if (image == null || image.path.isEmpty) return;
        final singleFile = File(image.path);
        if (!mounted) return;
        final MediaEditorResult? result =
            await Navigator.push<MediaEditorResult>(
          context,
          MaterialPageRoute(
            builder: (_) => MediaPreviewEditorScreen(file: singleFile),
          ),
        );
        if (result != null) {
          await _sendSingleProcessedMedia(
            file: result.file,
            isImage: true,
            caption: result.caption,
          );
        }
      } else if (type == 'document') {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
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
        if (result == null || result.files.isEmpty) return;
        final validFiles = result.files
            .where((f) => f.path != null && f.path!.isNotEmpty)
            .toList();
        if (validFiles.isEmpty) return;

        if (validFiles.length == 1) {
          final single = validFiles.first;
          final singleFile = File(single.path!);
          if (!mounted) return;
          final MediaEditorResult? editResult =
              await Navigator.push<MediaEditorResult>(
            context,
            MaterialPageRoute(
              builder: (_) => MediaPreviewEditorScreen(file: singleFile),
            ),
          );
          if (editResult != null) {
            await _sendSingleProcessedMedia(
              file: editResult.file,
              isImage: false,
              fileName: single.name,
              caption: editResult.caption,
            );
          }
        } else {
          setState(() {
            for (final f in validFiles) {
              _trayItems.add(
                TrayMediaItem(
                  id: '${DateTime.now().microsecondsSinceEpoch}_${f.name}',
                  file: File(f.path!),
                  isImage: false,
                  fileName: f.name,
                ),
              );
            }
          });
        }
      } else if (type == 'video') {
        final XFile? video =
            await _imagePicker.pickVideo(source: ImageSource.gallery);
        if (video != null && video.path.isNotEmpty) {
          final singleFile = File(video.path);
          if (!mounted) return;
          final MediaEditorResult? result =
              await Navigator.push<MediaEditorResult>(
            context,
            MaterialPageRoute(
              builder: (_) => MediaPreviewEditorScreen(
                file: singleFile,
                isVideo: true,
              ),
            ),
          );
          if (result != null) {
            setState(() => _isUploading = true);
            await _chatService.sendVideoFile(
              chatRoomId: _effectiveChatRoomId,
              senderId: widget.senderId,
              receiverId: widget.receiverId,
              file: result.file,
              caption: result.caption,
              messageCategory: _attachmentCategory,
            );
          }
        }
      } else if (type == 'audio') {
        final FilePickerResult? result =
            await FilePicker.platform.pickFiles(type: FileType.audio);
        if (result != null &&
            result.files.isNotEmpty &&
            result.files.single.path != null &&
            result.files.single.path!.isNotEmpty) {
          setState(() => _isUploading = true);
          await _chatService.sendAudioFile(
            chatRoomId: _effectiveChatRoomId,
            senderId: widget.senderId,
            receiverId: widget.receiverId,
            file: File(result.files.single.path!),
          );
        }
      } else if (type == 'location') {
        await _chatService.sendLocation(
          _effectiveChatRoomId,
          widget.senderId,
          widget.receiverId,
          22.5726,
          88.3639,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process attachment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _sendSingleProcessedMedia({
    required File file,
    required bool isImage,
    String? fileName,
    required String caption,
  }) async {
    if (mounted) setState(() => _isUploading = true);
    try {
      if (isImage) {
        await _chatService.sendImageFile(
          chatRoomId: _effectiveChatRoomId,
          senderId: widget.senderId,
          receiverId: widget.receiverId,
          file: file,
          caption: caption.trim().isNotEmpty ? caption.trim() : null,
          messageCategory: _attachmentCategory,
        );
      } else {
        await _chatService.sendDocumentFile(
          chatRoomId: _effectiveChatRoomId,
          senderId: widget.senderId,
          receiverId: widget.receiverId,
          file: file,
          fileName: fileName ?? file.path.split(Platform.pathSeparator).last,
          messageCategory: _attachmentCategory,
        );
        if (caption.trim().isNotEmpty) {
          await _chatService.sendMessage(
            chatId: _effectiveChatRoomId,
            senderId: widget.senderId,
            receiverId: widget.receiverId,
            message: caption.trim(),
            type: 'text',
            messageCategory: _attachmentCategory,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _handleTrayItemTap(TrayMediaItem item, int index) async {
    final MediaEditorResult? result = await Navigator.push<MediaEditorResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPreviewEditorScreen(
          file: item.file,
          initialCaption: item.caption,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        item.file = result.file;
        item.caption = result.caption;
      });
    }
  }

  void _handleTrayItemRemove(TrayMediaItem item, int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _trayItems.removeAt(index);
      _selectedTrayIds.remove(item.id);
    });
  }

  void _handleTrayItemToggleSelect(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_selectedTrayIds.contains(id)) {
        _selectedTrayIds.remove(id);
      } else {
        _selectedTrayIds.add(id);
      }
    });
  }

  void _handleClearSelection() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedTrayIds.clear();
    });
  }

  void _handleClearAllTray() {
    HapticFeedback.lightImpact();
    setState(() {
      _trayItems.clear();
      _selectedTrayIds.clear();
    });
  }

  Future<void> _sendTrayItems() async {
    final bool hasSelection = _selectedTrayIds.isNotEmpty;
    final List<TrayMediaItem> itemsToSend = hasSelection
        ? _trayItems.where((i) => _selectedTrayIds.contains(i.id)).toList()
        : List<TrayMediaItem>.from(_trayItems);

    if (itemsToSend.isEmpty) return;

    setState(() {
      _isUploading = true;
      if (hasSelection) {
        _trayItems.removeWhere((i) => _selectedTrayIds.contains(i.id));
        _selectedTrayIds.clear();
      } else {
        _trayItems.clear();
        _selectedTrayIds.clear();
      }
    });

    try {
      final List<TrayMediaItem> imageItems =
          itemsToSend.where((i) => i.isImage).toList();
      final List<TrayMediaItem> nonImageItems =
          itemsToSend.where((i) => !i.isImage).toList();

      if (imageItems.length > 1) {
        final List<File> files = imageItems.map((i) => i.file).toList();
        final String? firstCaption = imageItems
            .firstWhere(
              (i) => i.caption != null && i.caption!.trim().isNotEmpty,
              orElse: () => imageItems.first,
            )
            .caption;
        await _chatService.sendMediaAlbum(
          chatRoomId: _effectiveChatRoomId,
          senderId: widget.senderId,
          receiverId: widget.receiverId,
          files: files,
          caption: firstCaption,
          messageCategory: _attachmentCategory,
        );
      } else if (imageItems.length == 1) {
        final single = imageItems.first;
        await _chatService.sendImageFile(
          chatRoomId: _effectiveChatRoomId,
          senderId: widget.senderId,
          receiverId: widget.receiverId,
          file: single.file,
          caption: single.caption,
          messageCategory: _attachmentCategory,
        );
      }

      for (final item in nonImageItems) {
        await _chatService.sendDocumentFile(
          chatRoomId: _effectiveChatRoomId,
          senderId: widget.senderId,
          receiverId: widget.receiverId,
          file: item.file,
          fileName: item.fileName,
          messageCategory: _attachmentCategory,
        );
        if (item.caption != null && item.caption!.trim().isNotEmpty) {
          await _chatService.sendMessage(
            chatId: _effectiveChatRoomId,
            senderId: widget.senderId,
            receiverId: widget.receiverId,
            message: item.caption!.trim(),
            type: 'text',
            messageCategory: _attachmentCategory,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed sending media items: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _handleSend() async {
    if (_isUploading || widget.isMutedByTeacher) return;

    if (_trayItems.isNotEmpty) {
      await _sendTrayItems();
    }

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
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
    _chatService.updateTypingStatus(_effectiveChatRoomId, widget.senderId, false);

    if (widget.onCancelReply != null) {
      widget.onCancelReply!();
    }

    try {
      await _chatService.sendMessage(
        chatId: _effectiveChatRoomId,
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
        chatId: _effectiveChatRoomId,
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
    HapticFeedback.heavyImpact();
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
                        color: _brandBlue,
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
            valueColor: AlwaysStoppedAnimation<Color>(_brandBlue),
            minHeight: 2.5,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: const Border(
                left: BorderSide(color: _brandBlue, width: 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
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
                          color: _brandBlue,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.replyToText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.85),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.grey),
                  onPressed: widget.onCancelReply,
                ),
              ],
            ),
          ),
        if (_trayItems.isNotEmpty)
          MediaShortcutTray(
            items: _trayItems,
            selectedIds: _selectedTrayIds,
            onItemTap: _handleTrayItemTap,
            onItemRemove: _handleTrayItemRemove,
            onItemToggleSelect: _handleTrayItemToggleSelect,
            onClearSelection: _handleClearSelection,
            onClearAll: _handleClearAllTray,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          child: _isRecordingVoice
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(26),
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
                          backgroundColor: _brandBlue,
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
                          borderRadius: BorderRadius.circular(26.0),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryNavy.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: IconButton(
                                icon: Icon(
                                  _showEmojiPanel
                                      ? Icons.keyboard_alt_outlined
                                      : Icons.emoji_emotions_outlined,
                                  color: _showEmojiPanel
                                      ? _brandBlue
                                      : Colors.grey.shade600,
                                  size: 22,
                                ),
                                onPressed: _toggleEmojiPanel,
                              ),
                            ),
                            Expanded(
                              child: Scrollbar(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  keyboardType: TextInputType.multiline,
                                  minLines: 1,
                                  maxLines: 5,
                                  scrollPhysics: const BouncingScrollPhysics(),
                                  enabled: !_isUploading,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Type a message...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 10.0,
                                      horizontal: 4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: IconButton(
                                icon: Icon(Icons.attach_file_rounded,
                                    color: Colors.grey.shade600, size: 22),
                                onPressed: _isUploading
                                    ? null
                                    : _showAttachmentBottomSheet,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    GestureDetector(
                      onTap: _canSend ? _handleSend : _startVoiceNoteSession,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _canSend ? _accentBlue : _brandBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_canSend ? _accentBlue : _brandBlue)
                                  .withOpacity(0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: RotationTransition(
                                  turns: Tween<double>(begin: 0.75, end: 1.0)
                                      .animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: _canSend
                                ? const Icon(
                                    Icons.send_rounded,
                                    key: ValueKey('send_action_btn'),
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : const Icon(
                                    Icons.mic_rounded,
                                    key: ValueKey('mic_action_btn'),
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
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