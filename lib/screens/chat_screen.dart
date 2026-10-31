import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:find_your_best_teacher_today/models/message_model.dart';
import 'package:find_your_best_teacher_today/services/chat_menu_service.dart';
import 'package:find_your_best_teacher_today/services/chat_service.dart';
import 'package:find_your_best_teacher_today/services/local_chat_storage_service.dart';
import 'package:find_your_best_teacher_today/utils/popup_menu_actions.dart';
import 'package:find_your_best_teacher_today/widgets/block_dialog.dart';
import 'package:find_your_best_teacher_today/widgets/chat_gesture_tutorial_dialog.dart';
import 'package:find_your_best_teacher_today/widgets/chat_input_bar.dart';
import 'package:find_your_best_teacher_today/widgets/chat_popup_menu.dart';
import 'package:find_your_best_teacher_today/widgets/clear_chat_dialog.dart';
import 'package:find_your_best_teacher_today/widgets/delete_chat_dialog.dart';
import 'package:find_your_best_teacher_today/widgets/message_bubble.dart';
import 'package:find_your_best_teacher_today/widgets/report_dialog.dart';
import 'student_profile_screen.dart';
import 'teacher_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String receiverId;
  final String receiverName;
  final String receiverProfilePic;
  final String currentUserId;
  final bool isTeacher;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.receiverId,
    required this.receiverName,
    required this.receiverProfilePic,
    required this.currentUserId,
    required this.isTeacher,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final ChatMenuService _chatMenuService = ChatMenuService();
  final LocalChatStorageService _localStorage = LocalChatStorageService();
  final ScrollController _scrollController = ScrollController();

  final ValueNotifier<bool> _showScrollToBottomBtnNotifier =
      ValueNotifier<bool>(false);

  late String _activeChatRoomId;
  Stream<List<MessageModel>>? _messageStream;
  Stream>? _userStatusStream;
  Stream<DocumentSnapshot>? _typingDocStream;
  Stream<BlockStatus>? _blockStatusStream;
  List<MessageModel> _latestMessages = [];

  String? _replyToMessageId;
  String? _replyToText;
  String? _customBgImagePath;
  bool _isMarkingRead = false;
  bool _isInitializing = true;
  bool _isOffline = false;
  Timer? _connectivityTimer;
  int _lastMarkedCount = -1;

  bool _isDraggingMessage = false;
  bool _isDragHoveringInput = false;
  bool _didDropOnTarget = false;
  String? _hoveredTopAction;
  MessageModel? _draggedMessage;

  final Set<String> _selectedMessageIds = {};

  bool get _isSelectionMode => _selectedMessageIds.isNotEmpty;
  bool get _showTopActionBar => _isDraggingMessage || _isSelectionMode;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _scaffoldBg = Color(0xFFF8FAFC);

  bool get _isOfficialChannel =>
      widget.receiverId == 'OFFICIAL_FYBTT_DESK' ||
      widget.chatRoomId.startsWith('official_desk_');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final String teacherId =
        widget.isTeacher ? widget.currentUserId : widget.receiverId;
    final String studentId =
        widget.isTeacher ? widget.receiverId : widget.currentUserId;
    final String fallbackId = '${teacherId}_$studentId';

    _activeChatRoomId = widget.chatRoomId.trim().isNotEmpty
        ? widget.chatRoomId.trim()
        : (!_isOfficialChannel ? fallbackId : '');

    if (!_isOfficialChannel) {
      _userStatusStream = _chatService.getUserStatusStream(
        widget.receiverId,
        !widget.isTeacher,
      );
      _typingDocStream = FirebaseFirestore.instance
          .collection('typing')
          .doc(_activeChatRoomId)
          .snapshots()
          .handleError((error) => log('Typing Stream Error: $error'));
      _blockStatusStream = _chatMenuService.getBlockStatusStream(
        widget.currentUserId,
        widget.receiverId,
      );
    }

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 0.96), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.03), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0), weight: 15),
    ]).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
    );

    _scrollController.addListener(_onScrollChanged);
    _setupChatRoom();
    _loadCustomTheme();
    _startConnectivityMonitoring();

    if (!_isOfficialChannel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ChatGestureTutorialDialog.showIfNeeded(
            context,
            userId: widget.currentUserId,
            isGroup: false,
          );
        }
      });
    }
  }

  void _startConnectivityMonitoring() {
    _checkConnectivity();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 2));
      final bool hasNet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted && _isOffline == hasNet) {
        setState(() => _isOffline = !hasNet);
      }
    } catch (_) {
      if (mounted && !_isOffline) {
        setState(() => _isOffline = true);
      }
    }
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final bool shouldShow = _scrollController.offset > 280;
    if (_showScrollToBottomBtnNotifier.value != shouldShow) {
      _showScrollToBottomBtnNotifier.value = shouldShow;
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivityTimer?.cancel();
    _bounceController.dispose();
    if (!_isOfficialChannel) {
      _chatService.updateTypingStatus(
          _activeChatRoomId, widget.currentUserId, false);
    }
    _markMessagesAsReadSafe();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _showScrollToBottomBtnNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkConnectivity();
      _markMessagesAsReadSafe();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!_isOfficialChannel) {
        _chatService.updateTypingStatus(
            _activeChatRoomId, widget.currentUserId, false);
      }
    }
  }

  void _switchChatRoom(String newId) {
    if (!mounted || newId.isEmpty || newId == _activeChatRoomId) return;
    setState(() {
      _activeChatRoomId = newId;
      _messageStream = _chatService.getMessages(_activeChatRoomId);
      if (!_isOfficialChannel) {
        _typingDocStream = FirebaseFirestore.instance
            .collection('typing')
            .doc(_activeChatRoomId)
            .snapshots()
            .handleError((error) => log('Typing Stream Error: $error'));
      }
    });
    _loadCustomTheme();
    _markMessagesAsReadSafe();
  }

  Future<void> _setupChatRoom() async {
    if (widget.chatRoomId.trim().isEmpty && !_isOfficialChannel) {
      final String teacherId =
          widget.isTeacher ? widget.currentUserId : widget.receiverId;
      final String studentId =
          widget.isTeacher ? widget.receiverId : widget.currentUserId;
      final String expectedId = '${teacherId}_$studentId';

      try {
        final docSnap = await FirebaseFirestore.instance
            .collection('chats')
            .doc(expectedId)
            .get()
            .timeout(const Duration(seconds: 2));

        if (docSnap.exists) {
          _activeChatRoomId = expectedId;
        } else {
          final altDocSnap = await FirebaseFirestore.instance
              .collection('chats')
              .doc('${studentId}_$teacherId')
              .get()
              .timeout(const Duration(seconds: 2));

          if (altDocSnap.exists) {
            _activeChatRoomId = '${studentId}_$teacherId';
          } else {
            final querySnap = await FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: widget.currentUserId)
                .get()
                .timeout(const Duration(seconds: 2));

            for (final doc in querySnap.docs) {
              final participants = (doc.data()['participants'] as List?) ?? [];
              if (participants.contains(widget.receiverId)) {
                _activeChatRoomId = doc.id;
                break;
              }
            }
          }
        }
      } catch (_) {}
    }

    try {
      final cachedMsgs = await _localStorage.getMessages(_activeChatRoomId);
      if (cachedMsgs.isNotEmpty && mounted) {
        setState(() {
          _latestMessages = cachedMsgs;
          _isInitializing = false;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _messageStream = _chatService.getMessages(_activeChatRoomId);
        _isInitializing = false;
      });
    }

    if (_isOfficialChannel) {
      _markMessagesAsReadSafe();
      return;
    }

    _runBackgroundChatInit();
  }

  Future<void> _runBackgroundChatInit() async {
    try {
      String myName = 'User';
      String myImage = '';
      try {
        final profile = await _chatService
            .getUserProfile(
              widget.currentUserId,
              widget.isTeacher,
            )
            .timeout(const Duration(seconds: 2));
        if (profile != null) {
          myName = (profile['fullName'] ??
                  profile['name'] ??
                  profile['displayName'] ??
                  'User')
              .toString();
          myImage = (profile['profileImageUrl'] ??
                  profile['profilePic'] ??
                  profile['profileUrl'] ??
                  '')
              .toString();
        }
      } catch (_) {}

      final String teacherId =
          widget.isTeacher ? widget.currentUserId : widget.receiverId;
      final String studentId =
          widget.isTeacher ? widget.receiverId : widget.currentUserId;

      final String teacherName =
          widget.isTeacher ? myName : widget.receiverName;
      final String studentName =
          widget.isTeacher ? widget.receiverName : myName;

      final String teacherImage =
          widget.isTeacher ? myImage : widget.receiverProfilePic;
      final String studentImage =
          widget.isTeacher ? widget.receiverProfilePic : myImage;

      final dynamic initResult = await _chatService
          .createOrInitializeChat(
            teacherId: teacherId,
            studentId: studentId,
            teacherName: teacherName,
            studentName: studentName,
            teacherImage: teacherImage,
            studentImage: studentImage,
          )
          .timeout(const Duration(seconds: 3));

      if (initResult != null) {
        String? resolvedId;
        if (initResult is String && initResult.isNotEmpty) {
          resolvedId = initResult;
        } else if (initResult is DocumentReference) {
          resolvedId = initResult.id;
        } else if (initResult is DocumentSnapshot) {
          resolvedId = initResult.id;
        } else if (initResult is Map && initResult['chatId'] != null) {
          resolvedId = initResult['chatId'].toString();
        }
        if (resolvedId != null &&
            resolvedId.isNotEmpty &&
            resolvedId != _activeChatRoomId) {
          _switchChatRoom(resolvedId);
        }
      }

      if (mounted) {
        _chatService.updateTypingStatus(
            _activeChatRoomId, widget.currentUserId, false);
        _markMessagesAsReadSafe();
      }
    } catch (_) {}
  }

  Future<void> _markMessagesAsReadSafe() async {
    if (_isMarkingRead) return;
    _isMarkingRead = true;
    try {
      await _chatService.markAsSeen(_activeChatRoomId, widget.currentUserId);
    } catch (e) {
      log("Error marking as read: $e");
    } finally {
      if (mounted) {
        _isMarkingRead = false;
      }
    }
  }

  Future<void> _loadCustomTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _customBgImagePath = prefs.getString('chat_theme_$_activeChatRoomId');
      });
    }
  }

  Future<void> _changeChatThemeFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_theme_$_activeChatRoomId', pickedFile.path);
      if (mounted) {
        setState(() {
          _customBgImagePath = pickedFile.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chat wallpaper updated successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _primaryNavy,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _openFullScreenImageViewer(String imageUrl, String title) {
    if (imageUrl.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) {
          return Scaffold(
            backgroundColor: Colors.black.withOpacity(0.96),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: SizedBox.expand(
              child: Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(100),
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.broken_image_rounded,
                            color: Colors.white54, size: 48),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _canEditSingleMessage(MessageModel msg) {
    if (msg.senderId != widget.currentUserId) return false;
    if (msg.type.toLowerCase() != 'text') return false;
    if (msg.isDeletedForEveryone) return false;
    if (msg.timestamp == null) return false;
    final diff = DateTime.now().difference(msg.timestamp!);
    return diff.inMinutes < 5;
  }

  MessageModel? get _activeSingleTargetMessage {
    if (_isDraggingMessage && _draggedMessage != null) {
      return _draggedMessage;
    }
    if (_selectedMessageIds.length == 1) {
      final id = _selectedMessageIds.first;
      for (final m in _latestMessages) {
        if (m.messageId == id) return m;
      }
    }
    return null;
  }

  List<MessageModel> _getTargetMessages([MessageModel? droppedMessage]) {
    if (_selectedMessageIds.isNotEmpty) {
      return _latestMessages
          .where((m) => _selectedMessageIds.contains(m.messageId))
          .toList();
    }
    if (droppedMessage != null) {
      return [droppedMessage];
    }
    if (_draggedMessage != null) {
      return [_draggedMessage!];
    }
    return [];
  }

  void _toggleMessageSelection(MessageModel message) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedMessageIds.contains(message.messageId)) {
        _selectedMessageIds.remove(message.messageId);
      } else {
        _selectedMessageIds.add(message.messageId);
      }
    });
  }

  void _clearMessageSelection() {
    setState(() {
      _selectedMessageIds.clear();
      _isDraggingMessage = false;
      _draggedMessage = null;
      _hoveredTopAction = null;
      _isDragHoveringInput = false;
    });
  }

  void _triggerReply(MessageModel message) {
    if (_isOfficialChannel || message.isDeletedForEveryone) return;
    HapticFeedback.mediumImpact();
    _bounceController.forward(from: 0.0);
    setState(() {
      _selectedMessageIds.clear();
      _isDraggingMessage = false;
      _draggedMessage = null;
      _isDragHoveringInput = false;
      _replyToMessageId = message.messageId;
      _replyToText = _formatReplyPreviewText(message);
    });
  }

  String _formatReplyPreviewText(MessageModel message) {
    final t = message.type.toLowerCase();
    if (t == 'text') return message.content;
    if (t == 'image') return '📷 Photo';
    if (t == 'video') return '🎥 Video';
    if (t == 'audio' || t == 'voice') return '🎵 Voice message';
    if (t == 'document' || t == 'file') {
      return '📄 ${message.mediaMetaData?['fileName'] ?? 'Document'}';
    }
    if (t == 'location') return '📍 Shared Location';
    return message.content.isNotEmpty ? message.content : 'Attachment';
  }

  MessageModel _resolveMessageWithReplyText(MessageModel message) {
    if (message.replyToMessageId == null ||
        message.replyToMessageId!.trim().isEmpty) {
      return message;
    }
    if (message.replyText != null && message.replyText!.trim().isNotEmpty) {
      return message;
    }

    for (final m in _latestMessages) {
      if (m.messageId == message.replyToMessageId) {
        return message.copyWith(replyText: _formatReplyPreviewText(m));
      }
    }
    return message.copyWith(replyText: 'Original message');
  }

  void _scrollToOriginalMessage(String? replyToId) {
    if (replyToId == null || replyToId.isEmpty) return;
    final index =
        _latestMessages.indexWhere((m) => m.messageId == replyToId);
    if (index != -1 && _scrollController.hasClients) {
      final targetOffset = (index * 72.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  String _formatDateHeader(DateTime? date) {
    if (date == null) return 'Recent';
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatLastSeen(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';

    if (isToday) {
      return '$hour:$minute $amPm';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'yesterday at $hour:$minute $amPm';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} at $hour:$minute $amPm';
  }

  bool _isSameCalendarDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _openReceiverProfile() {
    if (_isOfficialChannel || widget.receiverId.isEmpty) return;
    if (widget.isTeacher) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentProfileScreen(currentUserId: widget.receiverId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeacherProfileScreen(currentUserId: widget.receiverId),
        ),
      );
    }
  }

  void _showEditMessageDialog(MessageModel msg) {
    if (!_canEditSingleMessage(msg)) return;
    final TextEditingController editCtrl =
        TextEditingController(text: msg.content);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: _brandBlue, size: 22),
              SizedBox(width: 8),
              Text(
                'Edit Message',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _primaryNavy,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: editCtrl,
            maxLines: null,
            autofocus: true,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: _primaryNavy,
            ),
            decoration: InputDecoration(
              hintText: 'Edit your message...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _accentBlue, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final newText = editCtrl.text.trim();
                Navigator.pop(dialogCtx);
                _clearMessageSelection();
                if (newText.isNotEmpty && newText != msg.content) {
                  await _chatService.editMessage(
                    _activeChatRoomId,
                    msg.messageId,
                    newText,
                    isGroup: false,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message edited')),
                    );
                  }
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeCopyMessages([MessageModel? droppedMsg]) async {
    final targets = _getTargetMessages(droppedMsg)
        .where((m) => !m.isDeletedForEveryone && m.content.trim().isNotEmpty)
        .toList();
    _clearMessageSelection();
    if (targets.isEmpty) return;

    final combinedText = targets.map((m) => m.content).join('\n');
    await Clipboard.setData(ClipboardData(text: combinedText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targets.length > 1
                ? '${targets.length} messages copied'
                : 'Copied to clipboard',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _primaryNavy,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _executeDeleteForMe([MessageModel? droppedMsg]) async {
    final targets = _getTargetMessages(droppedMsg);
    _clearMessageSelection();
    if (targets.isEmpty) return;

    for (final msg in targets) {
      try {
        await _chatService.deleteMessageForMe(
          _activeChatRoomId,
          msg.messageId,
          widget.currentUserId,
          isGroup: false,
        );
      } catch (e) {
        log("Delete for me error: $e");
      }
    }
  }

  Future<void> _executeDeleteForEveryone([MessageModel? droppedMsg]) async {
    final targets = _getTargetMessages(droppedMsg)
        .where((m) =>
            m.senderId == widget.currentUserId && !m.isDeletedForEveryone)
        .toList();
    _clearMessageSelection();
    if (targets.isEmpty) return;

    for (final msg in targets) {
      try {
        await _chatService.deleteMessageForEveryone(
          _activeChatRoomId,
          msg.messageId,
          isGroup: false,
        );
      } catch (e) {
        log("Delete for everyone error: $e");
      }
    }
  }

  Future<void> _clearChatSafe() async {
    await _localStorage.clearRoomLocally(_activeChatRoomId);

    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(_activeChatRoomId);
    final messagesSnap = await chatRef.collection('messages').get();

    const int chunkSize = 200;
    for (int i = 0; i < messagesSnap.docs.length; i += chunkSize) {
      final chunk = messagesSnap.docs.skip(i).take(chunkSize);
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await chatRef.set({
      'lastMessage': '',
      'lastMessageContent': '',
      'unreadCount_${widget.currentUserId}': 0,
    }, SetOptions(merge: true));
  }

  Future<void> _deleteConversationSafe() async {
    await _clearChatSafe();
    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(_activeChatRoomId);
    try {
      await chatRef.delete();
    } catch (_) {
      await chatRef.set({
        'deletedBy': FieldValue.arrayUnion([widget.currentUserId]),
      }, SetOptions(merge: true));
    }
  }

  void _confirmUnblockUser() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_open_rounded, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text(
              'Unblock User?',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: _primaryNavy,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to unblock ${widget.receiverName}? You will be able to send and receive messages again.',
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _chatMenuService.unblockUser(
                widget.currentUserId,
                widget.receiverId,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User unblocked successfully'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              'Unblock',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmBlockUser() {
    showDialog(
      context: context,
      builder: (context) => BlockDialog(
        userName: widget.receiverName,
        onConfirm: () async {
          await _chatMenuService.blockUser(
            widget.currentUserId,
            widget.receiverId,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User blocked successfully'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _handleMenuActionWithBlock(ChatMenuAction action, bool isBlockedByMe) {
    if (action == ChatMenuAction.blockUser) {
      if (isBlockedByMe) {
        _confirmUnblockUser();
      } else {
        _confirmBlockUser();
      }
    } else {
      _handleMenuAction(action);
    }
  }

  void _handleMenuAction(ChatMenuAction action) {
    switch (action) {
      case ChatMenuAction.viewProfile:
        _openReceiverProfile();
        break;

      case ChatMenuAction.blockUser:
        _confirmBlockUser();
        break;

      case ChatMenuAction.reportUser:
        showDialog(
          context: context,
          builder: (context) => ReportDialog(
            userName: widget.receiverName,
            onConfirm: (reason) async {
              await _chatMenuService.reportUser(
                  widget.currentUserId, widget.receiverId, reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User reported successfully')),
                );
              }
            },
          ),
        );
        break;

      case ChatMenuAction.clearChat:
        showDialog(
          context: context,
          builder: (context) => ClearChatDialog(
            onConfirm: () async {
              try {
                await _clearChatSafe();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat cleared successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to clear chat: $e')),
                  );
                }
              }
            },
          ),
        );
        break;

      case ChatMenuAction.deleteConversation:
        showDialog(
          context: context,
          builder: (context) => DeleteChatDialog(
            onConfirm: () async {
              try {
                await _deleteConversationSafe();
                if (mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Failed to delete conversation: $e')),
                  );
                }
              }
            },
          ),
        );
        break;
    }
  }

  Widget _buildTopActionIcon({
    required String actionKey,
    required IconData icon,
    required String tooltip,
    required Color color,
    required Function(MessageModel?) onExecute,
  }) {
    final bool isHovered = _hoveredTopAction == actionKey;

    return DragTarget<MessageModel>(
      onWillAcceptWithDetails: (details) {
        HapticFeedback.selectionClick();
        setState(() {
          _hoveredTopAction = actionKey;
        });
        return true;
      },
      onLeave: (_) {
        setState(() {
          if (_hoveredTopAction == actionKey) _hoveredTopAction = null;
        });
      },
      onAcceptWithDetails: (details) {
        _didDropOnTarget = true;
        HapticFeedback.heavyImpact();
        setState(() {
          _hoveredTopAction = null;
          _isDraggingMessage = false;
        });
        onExecute(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onExecute(null);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            transform: Matrix4.translationValues(0, isHovered ? -10.0 : 0.0, 0),
            child: AnimatedScale(
              scale: isHovered ? 1.5 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Tooltip(
                message: tooltip,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? color.withOpacity(0.28)
                        : Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isHovered
                          ? color
                          : Colors.white.withOpacity(0.22),
                      width: isHovered ? 1.8 : 1.0,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isHovered ? color : Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopActionToolbar() {
    final singleTarget = _activeSingleTargetMessage;
    final bool canEdit =
        singleTarget != null && _canEditSingleMessage(singleTarget);
    final targets = _getTargetMessages();
    final bool canDeleteForEveryone = !_isOfficialChannel &&
        targets.isNotEmpty &&
        targets.every((m) =>
            m.senderId == widget.currentUserId && !m.isDeletedForEveryone);

    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _primaryNavy.withOpacity(0.82),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (_isSelectionMode)
                    GestureDetector(
                      onTap: _clearMessageSelection,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close_rounded,
                                color: Colors.white, size: 17),
                            const SizedBox(width: 4),
                            Text(
                              '${_selectedMessageIds.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  _buildTopActionIcon(
                    actionKey: 'copy',
                    icon: Icons.copy_rounded,
                    tooltip: 'Copy',
                    color: Colors.cyanAccent,
                    onExecute: _executeCopyMessages,
                  ),
                  if (canEdit)
                    _buildTopActionIcon(
                      actionKey: 'edit',
                      icon: Icons.edit_rounded,
                      tooltip: 'Edit (within 5 mins)',
                      color: Colors.lightBlueAccent,
                      onExecute: (dropped) {
                        final msgToEdit = dropped ?? singleTarget;
                        if (msgToEdit != null) {
                          _showEditMessageDialog(msgToEdit);
                        }
                      },
                    ),
                  _buildTopActionIcon(
                    actionKey: 'delete_me',
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete for Me',
                    color: Colors.orangeAccent,
                    onExecute: _executeDeleteForMe,
                  ),
                  if (canDeleteForEveryone)
                    _buildTopActionIcon(
                      actionKey: 'delete_all',
                      icon: Icons.delete_forever_rounded,
                      tooltip: 'Delete for Everyone',
                      color: Colors.redAccent,
                      onExecute: _executeDeleteForEveryone,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfficialAppBarTitle() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () async {
            await _markMessagesAsReadSafe();
            if (context.mounted) Navigator.pop(context);
          },
        ),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF34D399).withOpacity(0.6),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                child: Icon(Icons.verified_rounded,
                    color: Colors.tealAccent, size: 20),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(
                    child: Text(
                      'FYBTT official',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Image.asset(
                    'assets/images/Verified_Batch.png',
                    width: 15,
                    height: 15,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF38BDF8),
                      size: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Verified Desk • Official Updates',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFA7F3D0),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStandardAppBarTitle() {
    return StreamBuilder>(
      stream: _userStatusStream,
      builder: (context, statusSnapshot) {
        String displayName = widget.receiverName;
        String displayPic = widget.receiverProfilePic;
        bool isOnline = false;
        bool isVerified = false;
        DateTime? lastSeenDate;

        if (statusSnapshot.hasData && statusSnapshot.data != null) {
          final data = statusSnapshot.data!;
          isVerified =
              data['isVerified'] == true || data['status'] == 'approved';

          final extractedName =
              (data['fullName'] ?? data['name'] ?? data['displayName'])
                  ?.toString();
          if (extractedName != null && extractedName.trim().isNotEmpty) {
            displayName = extractedName.trim();
          }
          final extractedPic = (data['profileImageUrl'] ??
                  data['profilePic'] ??
                  data['profileUrl'])
              ?.toString();
          if (extractedPic != null && extractedPic.trim().isNotEmpty) {
            displayPic = extractedPic.trim();
          }

          final bool rawIsOnline = data['isOnline'] == true;
          final dynamic lastSeenRaw = data['lastSeen'];
          if (lastSeenRaw is Timestamp) {
            lastSeenDate = lastSeenRaw.toDate();
            if (rawIsOnline) {
              final diff = DateTime.now().difference(lastSeenDate);
              isOnline = diff.inMinutes <= 3;
            }
          } else if (rawIsOnline) {
            isOnline = true;
          }
        }

        if (displayName.isEmpty || displayName == 'User') {
          displayName =
              widget.receiverName.isNotEmpty ? widget.receiverName : 'User';
        }

        final String initial = displayName.trim().isNotEmpty
            ? displayName.trim()[0].toUpperCase()
            : 'U';

        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () async {
                _chatService.updateTypingStatus(
                    _activeChatRoomId, widget.currentUserId, false);
                await _markMessagesAsReadSafe();
                if (context.mounted) Navigator.pop(context);
              },
            ),
            GestureDetector(
              onTap: () {
                if (displayPic.isNotEmpty) {
                  _openFullScreenImageViewer(displayPic, displayName);
                } else {
                  _openReceiverProfile();
                }
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isOnline
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withOpacity(0.35),
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1E293B),
                      backgroundImage: displayPic.isNotEmpty
                          ? NetworkImage(displayPic)
                          : null,
                      child: displayPic.isEmpty
                          ? Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10.5,
                        height: 10.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _primaryNavy, width: 1.8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _openReceiverProfile,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 15.8,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF38BDF8),
                            size: 15,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _typingDocStream,
                      builder: (context, typingSnapshot) {
                        bool isTyping = false;
                        if (typingSnapshot.hasData &&
                            typingSnapshot.data!.exists) {
                          final data = typingSnapshot.data!.data()
                              as Map<String, dynamic>?;
                          isTyping = data?[widget.receiverId] == true;
                        }

                        if (isTyping) {
                          return const Row(
                            children: [
                              Text(
                                'typing...',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF5EEAD4),
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          );
                        }

                        String statusSubtitle = 'Tap to view profile';
                        if (isOnline) {
                          statusSubtitle = 'Online • Tap for profile';
                        } else if (lastSeenDate != null) {
                          statusSubtitle =
                              'Last seen ${_formatLastSeen(lastSeenDate!)} • Tap for profile';
                        }

                        return Text(
                          statusSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isOnline
                                ? const Color(0xFF86EFAC)
                                : Colors.white70,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOfflineBanner() {
    if (!_isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4.5, horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFEF4444),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text(
            'You are offline • Showing cached chats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isSelectionMode) {
          _clearMessageSelection();
          return;
        }
        if (!_isOfficialChannel) {
          _chatService.updateTypingStatus(
              _activeChatRoomId, widget.currentUserId, false);
        }
        await _markMessagesAsReadSafe();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _scaffoldBg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: _primaryNavy,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryNavy,
                  Color(0xFF1E3A8A),
                  _brandBlue,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 0,
          titleSpacing: 0,
          scrolledUnderElevation: 0,
          title: _isOfficialChannel
              ? _buildOfficialAppBarTitle()
              : _buildStandardAppBarTitle(),
          actions: [
            IconButton(
              icon: const Icon(Icons.wallpaper_rounded,
                  color: Colors.white, size: 21),
              tooltip: 'Change Chat Theme',
              onPressed: _changeChatThemeFromGallery,
            ),
            if (!_isOfficialChannel)
              StreamBuilder<BlockStatus>(
                stream: _blockStatusStream,
                initialData: const BlockStatus(
                  isBlockedByMe: false,
                  isBlockedByOther: false,
                ),
                builder: (context, blockSnap) {
                  final blockStatus = blockSnap.data ??
                      const BlockStatus(
                        isBlockedByMe: false,
                        isBlockedByOther: false,
                      );
                  return ChatPopupMenu(
                    isBlockedByMe: blockStatus.isBlockedByMe,
                    onSelected: (action) => _handleMenuActionWithBlock(
                      action,
                      blockStatus.isBlockedByMe,
                    ),
                  );
                },
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            color: _scaffoldBg,
            image: _customBgImagePath != null
                ? DecorationImage(
                    image: FileImage(File(_customBgImagePath!)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: _isInitializing && _latestMessages.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: _brandBlue,
                              strokeWidth: 3,
                            ),
                          )
                        : StreamBuilder<List<MessageModel>>(
                            stream: _messageStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasError && _latestMessages.isEmpty) {
                                return Center(
                                  child: Text(
                                    'Failed to load messages.',
                                    style: TextStyle(
                                      color: Colors.red.shade400,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }

                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  _latestMessages.isEmpty) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: _brandBlue,
                                    strokeWidth: 3,
                                  ),
                                );
                              }

                              final rawMessages =
                                  snapshot.data ?? _latestMessages;
                              _latestMessages = rawMessages
                                  .where((m) => !m.deletedForUsers
                                      .contains(widget.currentUserId))
                                  .toList();

                              if (_latestMessages.isEmpty) {
                                return Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _primaryNavy.withOpacity(0.04),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isOfficialChannel
                                              ? Icons.campaign_rounded
                                              : Icons.lock_outline_rounded,
                                          size: 17,
                                          color: _brandBlue,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isOfficialChannel
                                              ? 'Official notice channel'
                                              : 'Messages are end-to-end encrypted',
                                          style: const TextStyle(
                                            color: _primaryNavy,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              if (_lastMarkedCount != _latestMessages.length) {
                                _lastMarkedCount = _latestMessages.length;
                                WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => _markMessagesAsReadSafe());
                              }

                              return ListView.builder(
                                key: PageStorageKey<String>(
                                    'private_chat_$_activeChatRoomId'),
                                controller: _scrollController,
                                reverse: true,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: EdgeInsets.only(
                                  left: 12,
                                  right: 12,
                                  top: _showTopActionBar ? 74 : 12,
                                  bottom: 12,
                                ),
                                itemCount: _latestMessages.length,
                                itemBuilder: (context, index) {
                                  final rawMsg = _latestMessages[index];
                                  final message =
                                      _resolveMessageWithReplyText(rawMsg);
                                  final bool isMe =
                                      message.senderId == widget.currentUserId;
                                  final bool isSelected = _selectedMessageIds
                                      .contains(message.messageId);

                                  final bool showDateHeader = index ==
                                          _latestMessages.length - 1 ||
                                      !_isSameCalendarDay(
                                        message.timestamp,
                                        _latestMessages[index + 1].timestamp,
                                      );

                                  return Column(
                                    key: ValueKey(message.messageId),
                                    crossAxisAlignment: isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      if (showDateHeader)
                                        Center(
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 10),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _primaryNavy
                                                  .withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _formatDateHeader(
                                                  message.timestamp),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ),
                                      GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onTap: _isSelectionMode
                                            ? () => _toggleMessageSelection(
                                                message)
                                            : null,
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? _accentBlue.withOpacity(0.14)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                            children: [
                                              if (_isSelectionMode)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 6, right: 2),
                                                  child: Icon(
                                                    isSelected
                                                        ? Icons
                                                            .check_circle_rounded
                                                        : Icons
                                                            .radio_button_unchecked_rounded,
                                                    color: isSelected
                                                        ? _accentBlue
                                                        : Colors.grey.shade400,
                                                    size: 20,
                                                  ),
                                                ),
                                              Expanded(
                                                child: LongPressDraggable<
                                                    MessageModel>(
                                                  delay: const Duration(
                                                      milliseconds: 500),
                                                  data: message,
                                                  onDragStarted: () {
                                                    HapticFeedback
                                                        .mediumImpact();
                                                    setState(() {
                                                      _didDropOnTarget = false;
                                                      _isDraggingMessage = true;
                                                      _draggedMessage = message;
                                                    });
                                                  },
                                                  onDragUpdate: (details) {
                                                    if (_isOfficialChannel) {
                                                      return;
                                                    }
                                                    final screenH =
                                                        MediaQuery.of(context)
                                                            .size
                                                            .height;
                                                    final bottomInset =
                                                        MediaQuery.of(context)
                                                            .viewInsets
                                                            .bottom;
                                                    final replyTriggerLine =
                                                        screenH -
                                                            bottomInset -
                                                            140;
                                                    final nearInput = details
                                                            .globalPosition
                                                            .dy >=
                                                        replyTriggerLine;
                                                    if (nearInput !=
                                                        _isDragHoveringInput) {
                                                      HapticFeedback
                                                          .selectionClick();
                                                      setState(() {
                                                        _isDragHoveringInput =
                                                            nearInput;
                                                      });
                                                    }
                                                  },
                                                  onDragEnd: (details) {
                                                    if (_isDragHoveringInput &&
                                                        !_didDropOnTarget &&
                                                        _draggedMessage !=
                                                            null) {
                                                      _didDropOnTarget = true;
                                                      _triggerReply(
                                                          _draggedMessage!);
                                                      return;
                                                    }

                                                    setState(() {
                                                      _isDraggingMessage =
                                                          false;
                                                      if (!_didDropOnTarget) {
                                                        _selectedMessageIds.add(
                                                            message.messageId);
                                                      }
                                                      _draggedMessage = null;
                                                      _hoveredTopAction = null;
                                                      _isDragHoveringInput =
                                                          false;
                                                    });
                                                  },
                                                  feedback: Material(
                                                    color: Colors.transparent,
                                                    child: Transform.scale(
                                                      scale: 1.06,
                                                      child: Container(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.85,
                                                        decoration:
                                                            BoxDecoration(
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: _primaryNavy
                                                                  .withOpacity(
                                                                      0.26),
                                                              blurRadius: 20,
                                                              spreadRadius: 2,
                                                              offset:
                                                                  const Offset(
                                                                      0, 8),
                                                            ),
                                                          ],
                                                        ),
                                                        child: IgnorePointer(
                                                          child: MessageBubble(
                                                            message: message,
                                                            isMe: isMe,
                                                            chatRoomId:
                                                                _activeChatRoomId,
                                                            currentUserId: widget
                                                                .currentUserId,
                                                            onReplyPressed:
                                                                (_) {},
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  childWhenDragging: Opacity(
                                                    opacity: 0.25,
                                                    child: IgnorePointer(
                                                      child: MessageBubble(
                                                        message: message,
                                                        isMe: isMe,
                                                        chatRoomId:
                                                            _activeChatRoomId,
                                                        currentUserId:
                                                            widget.currentUserId,
                                                        onReplyPressed: (_) {},
                                                      ),
                                                    ),
                                                  ),
                                                  child: MessageBubble(
                                                    message: message,
                                                    isMe: isMe,
                                                    chatRoomId:
                                                        _activeChatRoomId,
                                                    currentUserId:
                                                        widget.currentUserId,
                                                    onReplyPressed:
                                                        (repliedMessage) {
                                                      _triggerReply(
                                                          repliedMessage);
                                                    },
                                                    onReplyPreviewTap: () =>
                                                        _scrollToOriginalMessage(
                                                            message
                                                                .replyToMessageId),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  _buildOfflineBanner(),
                  if (_isOfficialChannel)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 14,
                        bottom: MediaQuery.of(context).padding.bottom + 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Only official announcements are delivered here.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    StreamBuilder<BlockStatus>(
                      stream: _blockStatusStream,
                      initialData: const BlockStatus(
                        isBlockedByMe: false,
                        isBlockedByOther: false,
                      ),
                      builder: (context, blockSnap) {
                        final status = blockSnap.data ??
                            const BlockStatus(
                              isBlockedByMe: false,
                              isBlockedByOther: false,
                            );

                        if (status.isBlockedByMe) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              border: const Border(
                                top: BorderSide(color: Color(0xFFFECACA)),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: SafeArea(
                              top: false,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.block_rounded,
                                      size: 19, color: Color(0xFFDC2626)),
                                  const SizedBox(width: 8),
                                  const Flexible(
                                    child: Text(
                                      'You blocked this contact.',
                                      style: TextStyle(
                                        color: Color(0xFF991B1B),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: _confirmUnblockUser,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'Unblock',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (status.isBlockedByOther) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              border: const Border(
                                top: BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: const SafeArea(
                              top: false,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 18, color: Color(0xFF64748B)),
                                  SizedBox(width: 8),
                                  Text(
                                    'You cannot send messages to this contact.',
                                    style: TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return DragTarget<MessageModel>(
                          onWillAcceptWithDetails: (details) {
                            HapticFeedback.selectionClick();
                            setState(() => _isDragHoveringInput = true);
                            return true;
                          },
                          onLeave: (_) {
                            setState(() => _isDragHoveringInput = false);
                          },
                          onAcceptWithDetails: (details) {
                            _didDropOnTarget = true;
                            setState(() => _isDragHoveringInput = false);
                            _triggerReply(details.data);
                          },
                          builder: (context, candidateData, rejectedData) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: _isDragHoveringInput ? 34 : 0,
                                  width: double.infinity,
                                  color: _primaryNavy,
                                  alignment: Alignment.center,
                                  child: _isDragHoveringInput
                                      ? const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.reply_rounded,
                                                color: Colors.white, size: 17),
                                            SizedBox(width: 6),
                                            Text(
                                              'Release here to Reply',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                                AnimatedScale(
                                  scale: _isDragHoveringInput ? 1.04 : 1.0,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.elasticOut,
                                  child: ScaleTransition(
                                    scale: _bounceAnimation,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: _isDragHoveringInput
                                            ? Border.all(
                                                color: _accentBlue, width: 2.2)
                                            : null,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _isDragHoveringInput
                                                ? _accentBlue.withOpacity(0.28)
                                                : Colors.black
                                                    .withOpacity(0.04),
                                            blurRadius:
                                                _isDragHoveringInput ? 18 : 10,
                                            offset: const Offset(0, -3),
                                          ),
                                        ],
                                      ),
                                      child: ChatInputBar(
                                        chatRoomId: _activeChatRoomId,
                                        senderId: widget.currentUserId,
                                        receiverId: widget.receiverId,
                                        replyToMessageId: _replyToMessageId,
                                        replyToText: _replyToText,
                                        onCancelReply: () {
                                          setState(() {
                                            _replyToMessageId = null;
                                            _replyToText = null;
                                          });
                                        },
                                        onTypingChanged: (isTyping) {
                                          _chatService.updateTypingStatus(
                                              _activeChatRoomId,
                                              widget.currentUserId,
                                              isTyping);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
              if (_showTopActionBar) _buildTopActionToolbar(),
              ValueListenableBuilder<bool>(
                valueListenable: _showScrollToBottomBtnNotifier,
                builder: (context, showBtn, _) {
                  if (!showBtn) return const SizedBox.shrink();
                  return Positioned(
                    right: 16,
                    bottom: 84,
                    child: FloatingActionButton.small(
                      backgroundColor: _primaryNavy,
                      onPressed: _scrollToBottom,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
