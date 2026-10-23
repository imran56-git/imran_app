import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/group_model.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../services/group_service.dart';
import '../../services/media_service.dart';
import '../../widgets/academic_composer_sheet.dart';
import '../../widgets/chat_gesture_tutorial_dialog.dart';
import '../../widgets/chat_input_bar.dart';
import '../../widgets/message_bubble.dart';
import 'ai_study_assistant_sheet.dart';
import 'group_info_screen.dart';
import 'media_docs_links_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupName;
  final String groupId;
  final String currentUserId;
  final String currentUserName;

  const GroupChatScreen({
    super.key,
    required this.groupName,
    required this.groupId,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final GroupService _groupService = GroupService();
  final MediaService _mediaService = MediaService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  late Stream<List<MessageModel>> _messagesStream;

  final ValueNotifier<bool> _showScrollToBottomBtnNotifier =
      ValueNotifier<bool>(false);

  StreamSubscription<GroupModel?>? _groupSubscription;
  GroupModel? _currentGroup;
  List<MessageModel> _latestMessages = [];
  late String _activeUserName;

  String? _replyToMessageId;
  String? _replyToText;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isSearching = false;
  bool _exitDialogShown = false;
  int _initialUnreadCount = 0;
  bool _capturedInitialUnread = false;

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

  final String _backgroundImage = 'assets/images/chat_bg.png';

  final List<Map<String, dynamic>> _categories = [
    {'key': 'all', 'label': 'All', 'icon': Icons.all_inbox_rounded},
    {
      'key': 'announcement',
      'label': 'Announcements',
      'icon': Icons.campaign_rounded
    },
    {'key': 'homework', 'label': 'Homework', 'icon': Icons.menu_book_rounded},
    {
      'key': 'assignment',
      'label': 'Assignments',
      'icon': Icons.assignment_rounded
    },
    {
      'key': 'study_material',
      'label': 'Study Material',
      'icon': Icons.library_books_rounded
    },
    {'key': 'doubt', 'label': 'Doubts', 'icon': Icons.help_outline_rounded},
    {'key': 'poll', 'label': 'Polls', 'icon': Icons.poll_rounded},
    {'key': 'quiz', 'label': 'Quizzes', 'icon': Icons.quiz_rounded},
    {
      'key': 'exam_notice',
      'label': 'Exam Notices',
      'icon': Icons.event_note_rounded
    },
  ];

  @override
  void initState() {
    super.initState();
    _activeUserName = widget.currentUserName.trim().isEmpty
        ? 'User'
        : widget.currentUserName.trim();

    _resolveActiveUserName();

    _messagesStream = _chatService.getGroupMessagesStream(
      widget.groupId,
      categoryFilter: _selectedCategory,
    );

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
    _listenToGroupRealtimeState();
    _chatService.markGroupMessagesAsSeen(widget.groupId, widget.currentUserId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ChatGestureTutorialDialog.showIfNeeded(
          context,
          userId: widget.currentUserId,
          isGroup: true,
        );
      }
    });
  }

  Future<void> _resolveActiveUserName() async {
    if (_activeUserName != 'User') return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();
      if (doc.exists && doc.data() != null && mounted) {
        final data = doc.data()!;
        final name = (data['name'] ?? data['fullName'] ?? data['displayName'])
            ?.toString();
        if (name != null && name.trim().isNotEmpty) {
          setState(() {
            _activeUserName = name.trim();
          });
        }
      }
    } catch (_) {}
  }

  void _updateCategoryFilter(String newCategory) {
    if (_selectedCategory == newCategory) return;
    setState(() {
      _selectedCategory = newCategory;
      _messagesStream = _chatService.getGroupMessagesStream(
        widget.groupId,
        categoryFilter: _selectedCategory,
      );
    });
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final bool shouldShow = _scrollController.offset > 280;
    if (_showScrollToBottomBtnNotifier.value != shouldShow) {
      _showScrollToBottomBtnNotifier.value = shouldShow;
    }
  }

  void _listenToGroupRealtimeState() {
    _groupSubscription =
        _groupService.getGroupStream(widget.groupId).listen((group) {
      if (!mounted) return;

      if (group == null) {
        _triggerForcedExitDialog(isDismissal: true, teacherName: 'Teacher');
        return;
      }

      if (!_capturedInitialUnread) {
        _initialUnreadCount = group.getUnreadCountForUser(widget.currentUserId);
        _capturedInitialUnread = true;
      }

      final bool wasMuted =
          _currentGroup?.isStudentMuted(widget.currentUserId) ?? false;
      final bool isNowMuted = group.isStudentMuted(widget.currentUserId);
      if (!wasMuted && isNowMuted) {
        FocusScope.of(context).unfocus();
      }

      setState(() {
        _currentGroup = group;
      });

      final bool isTeacher = group.isSingleAdmin(widget.currentUserId);
      if (!isTeacher) {
        if (group.isDismissed ||
            group.unacknowledgedDismissMembers.contains(widget.currentUserId)) {
          _triggerForcedExitDialog(
            isDismissal: true,
            teacherName:
                group.teacherName.isNotEmpty ? group.teacherName : 'Teacher',
          );
          return;
        }

        if (group.isStudentRemoved(widget.currentUserId) ||
            group.pendingRemovalNotices.contains(widget.currentUserId) ||
            !group.members.contains(widget.currentUserId)) {
          _triggerForcedExitDialog(
            isDismissal: false,
            teacherName:
                group.teacherName.isNotEmpty ? group.teacherName : 'Teacher',
          );
          return;
        }
      }
    });
  }

  Future<void> _triggerForcedExitDialog({
    required bool isDismissal,
    required String teacherName,
  }) async {
    if (_exitDialogShown || !mounted) return;
    _exitDialogShown = true;
    FocusScope.of(context).unfocus();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDismissal
                      ? Icons.cancel_outlined
                      : Icons.person_remove_alt_1_rounded,
                  color: Colors.red.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _currentGroup?.name ?? widget.groupName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            isDismissal
                ? "This group has been dismissed by the teacher."
                : "You have been removed from this group by the teacher.",
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  Navigator.of(dialogCtx).pop();
                  try {
                    if (isDismissal) {
                      await _groupService.acknowledgeGroupDismissal(
                        groupId: widget.groupId,
                        studentId: widget.currentUserId,
                      );
                    } else {
                      await _groupService.acknowledgeStudentRemoval(
                        groupId: widget.groupId,
                        studentId: widget.currentUserId,
                      );
                    }
                  } catch (_) {}
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  isDismissal ? "Continue" : "OK",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _groupSubscription?.cancel();
    _bounceController.dispose();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _showScrollToBottomBtnNotifier.dispose();
    _searchController.dispose();
    _chatService.markGroupMessagesAsSeen(widget.groupId, widget.currentUserId);
    super.dispose();
  }

  ImageProvider? _buildBackgroundProvider() {
    try {
      if (_backgroundImage.startsWith('assets/')) {
        return AssetImage(_backgroundImage);
      }
      return FileImage(File(_backgroundImage));
    } catch (_) {
      return null;
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool get _isViewerTeacher {
    return _currentGroup?.isSingleAdmin(widget.currentUserId) ?? false;
  }

  bool get _isStudentMuted {
    if (_isViewerTeacher) return false;
    return _currentGroup?.isStudentMuted(widget.currentUserId) ?? false;
  }

  bool get _isPostingRestrictedToAdmin {
    if (_isViewerTeacher) return false;
    return _currentGroup?.onlyAdminCanPost ?? false;
  }

  bool get _canCurrentUserReply {
    if (_currentGroup != null && _currentGroup!.isDismissed) return false;
    if (_isStudentMuted || _isPostingRestrictedToAdmin) return false;
    return true;
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

  String _formatReplyPreviewText(MessageModel message) {
    final t = message.type.toLowerCase();
    if (t == 'text') return message.content;
    if (t == 'image') return '📷 Photo';
    if (t == 'video') return '🎥 Video';
    if (t == 'audio' || t == 'voice') return '🎵 Voice message';
    if (t == 'document' || t == 'file') {
      return '📄 ${message.mediaMetaData?['fileName'] ?? 'Document'}';
    }
    if (t == 'poll') return '📊 Poll: ${message.content}';
    if (t == 'quiz') return '📝 Quiz: ${message.content}';
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
      final targetOffset = (index * 78.0).clamp(
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

  void _triggerReply(MessageModel message) {
    if (!_canCurrentUserReply || message.isDeletedForEveryone) return;
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

  void _showEditMessageDialog(MessageModel msg) {
    if (!_canEditSingleMessage(msg)) return;
    final TextEditingController editCtrl =
        TextEditingController(text: msg.content);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Edit Message',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: editCtrl,
            maxLines: null,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Edit your message...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final newText = editCtrl.text.trim();
                Navigator.pop(dialogCtx);
                _clearMessageSelection();
                if (newText.isNotEmpty && newText != msg.content) {
                  await _chatService.editMessage(
                    widget.groupId,
                    msg.messageId,
                    newText,
                    isGroup: true,
                  );
                  _showSnackBar('Message edited');
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
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
    _showSnackBar(
      targets.length > 1
          ? '${targets.length} messages copied'
          : 'Copied to clipboard',
    );
  }

  Future<void> _executeDeleteForMe([MessageModel? droppedMsg]) async {
    final targets = _getTargetMessages(droppedMsg);
    _clearMessageSelection();
    if (targets.isEmpty) return;

    for (final msg in targets) {
      await _chatService.deleteMessageForMe(
        widget.groupId,
        msg.messageId,
        widget.currentUserId,
        isGroup: true,
      );
    }
  }

  Future<void> _executeDeleteForEveryone([MessageModel? droppedMsg]) async {
    final targets = _getTargetMessages(droppedMsg)
        .where((m) =>
            (m.senderId == widget.currentUserId || _isViewerTeacher) &&
            !m.isDeletedForEveryone)
        .toList();
    _clearMessageSelection();
    if (targets.isEmpty) return;

    for (final msg in targets) {
      await _chatService.deleteMessageForEveryone(
        widget.groupId,
        msg.messageId,
        isGroup: true,
      );
    }
  }

  Future<void> _executeTogglePin([MessageModel? droppedMsg]) async {
    if (!_isViewerTeacher) return;
    final msg = droppedMsg ?? _activeSingleTargetMessage;
    _clearMessageSelection();
    if (msg == null) return;

    await _groupService.togglePinMessage(
      groupId: widget.groupId,
      teacherId: widget.currentUserId,
      messageId: msg.messageId,
      pin: !msg.isPinned,
    );
    _showSnackBar(msg.isPinned ? 'Message unpinned' : 'Message pinned');
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
    final bool canDeleteForEveryone = targets.isNotEmpty &&
        targets.every((m) =>
            (m.senderId == widget.currentUserId || _isViewerTeacher) &&
            !m.isDeletedForEveryone);

    return Positioned(
      top: 52,
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
                color: const Color(0xFF0F172A).withOpacity(0.78),
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
                  if (_isViewerTeacher && singleTarget != null)
                    _buildTopActionIcon(
                      actionKey: 'pin',
                      icon: singleTarget.isPinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin_rounded,
                      tooltip: singleTarget.isPinned ? 'Unpin' : 'Pin Message',
                      color: Colors.amberAccent,
                      onExecute: _executeTogglePin,
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

  bool _isSameCalendarDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _showStudentModerationDialog({
    required String studentId,
    required String studentName,
  }) {
    if (!_isViewerTeacher || studentId == widget.currentUserId) return;
    final bool isMuted = _currentGroup?.isStudentMuted(studentId) ?? false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      studentName.isNotEmpty
                          ? studentName[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "UID: $studentId",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    isMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                    color: isMuted ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                    isMuted
                        ? "Unmute Student (Allow sending messages)"
                        : "Mute Student Temporarily",
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await _groupService.setStudentMuteStatus(
                        groupId: widget.groupId,
                        teacherId: widget.currentUserId,
                        studentId: studentId,
                        mute: !isMuted,
                      );
                      _showSnackBar(
                        isMuted
                            ? "$studentName has been unmuted."
                            : "$studentName has been muted.",
                      );
                    } catch (e) {
                      _showSnackBar("Action failed: $e");
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.person_remove_alt_1_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    "Remove Student from Group",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmRemoveStudent(studentId, studentName);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmRemoveStudent(String studentId, String studentName) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Remove Student?"),
          content: Text(
            "Are you sure you want to remove $studentName from this group? They will be notified and will no longer have access.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _groupService.removeStudentFromGroup(
                    groupId: widget.groupId,
                    teacherId: widget.currentUserId,
                    studentId: studentId,
                  );
                  _showSnackBar("$studentName removed from group.");
                } catch (e) {
                  _showSnackBar("Error: $e");
                }
              },
              child:
                  const Text("Remove", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDismissGroup() {
    if (!_isViewerTeacher) return;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Dismiss Group Permanently",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            "Once dismissed, this group will be permanently closed. Every student in this group will receive a real-time dismissal popup and no further messages can be sent.",
            style: TextStyle(fontSize: 14.5, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _groupService.dismissGroup(
                    groupId: widget.groupId,
                    teacherId: widget.currentUserId,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    _showSnackBar("Group has been permanently dismissed.");
                  }
                } catch (e) {
                  _showSnackBar("Failed to dismiss group: $e");
                }
              },
              child: const Text(
                "Dismiss Group",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openAcademicComposerSheet() {
    AcademicComposerSheet.show(
      context,
      groupId: widget.groupId,
      currentUserId: widget.currentUserId,
      isTeacher: _isViewerTeacher,
    );
  }

  void _openAiStudyAssistantSheet() {
    AiStudyAssistantSheet.show(
      context,
      groupId: widget.groupId,
      groupName: _currentGroup?.name ?? widget.groupName,
      currentUserId: widget.currentUserId,
      isTeacher: _isViewerTeacher,
      subjectName: _currentGroup?.subjectName ?? '',
    );
  }

  void _openGroupInfoPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupInfoScreen(
          groupId: widget.groupId,
          currentUserId: widget.currentUserId,
          currentUserName: _activeUserName,
          onOpenMediaDocsLinks: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MediaDocsLinksScreen(
                  chatOrGroupId: widget.groupId,
                  title: _currentGroup?.name ?? widget.groupName,
                  currentUserId: widget.currentUserId,
                  isGroup: true,
                  isViewerTeacherOfGroup: _isViewerTeacher,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryFilterBar() {
    return Container(
      height: 44,
      color: const Color(0xFF0F172A),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final bool isSelected = _selectedCategory == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _updateCategoryFilter(cat['key'] as String),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blueAccent
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: 14,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPinnedMessageBanner(List<MessageModel> messages) {
    final pinnedList = messages.where((m) => m.isPinned).toList();
    if (pinnedList.isEmpty) return const SizedBox.shrink();
    final latestPinned = pinnedList.first;

    return GestureDetector(
      onTap: () => _scrollToOriginalMessage(latestPinned.messageId),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.amber.shade200),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.push_pin_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Pinned Announcement",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                  ),
                  Text(
                    latestPinned.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12.5, color: Colors.black87),
                  ),
                ],
              ),
            ),
            if (_isViewerTeacher)
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.brown),
                onPressed: () {
                  _groupService.togglePinMessage(
                    groupId: widget.groupId,
                    teacherId: widget.currentUserId,
                    messageId: latestPinned.messageId,
                    pin: false,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractivePollOrQuizCard(MessageModel message, bool isMe) {
    if (message.type == 'poll' && message.pollData != null) {
      final poll = message.pollData!;
      final String question = (poll['question'] ?? message.content).toString();
      final List<dynamic> options =
          (poll['options'] as List<dynamic>?) ?? const [];
      final Map<String, dynamic> votes = poll['votes'] is Map
          ? Map<String, dynamic>.from(poll['votes'] as Map)
          : {};
      final int totalVotes = votes.length;
      final int? myVote = votes[widget.currentUserId] is int
          ? votes[widget.currentUserId] as int
          : int.tryParse(votes[widget.currentUserId]?.toString() ?? '');

      return Container(
        key: ValueKey('poll_${message.messageId}'),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.poll_rounded, color: Colors.blueAccent, size: 18),
                SizedBox(width: 6),
                Text(
                  "CLASS POLL",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              question,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(options.length, (i) {
              final int count =
                  votes.values.where((v) => v.toString() == '$i').length;
              final double ratio = totalVotes > 0 ? count / totalVotes : 0.0;
              final bool isSelected = myVote == i;

              final optionCard = Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.shade50
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.blueAccent
                        : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            options[i].toString(),
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        Text(
                          "$count (${(ratio * 100).toStringAsFixed(0)}%)",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: Colors.grey.shade200,
                      color: Colors.blueAccent,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _isStudentMuted
                    ? optionCard
                    : GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          _groupService.voteOnPoll(
                            groupId: widget.groupId,
                            messageId: message.messageId,
                            userId: widget.currentUserId,
                            optionIndex: i,
                          );
                        },
                        child: optionCard,
                      ),
              );
            }),
            Text(
              "$totalVotes total vote${totalVotes == 1 ? '' : 's'}",
              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (message.type == 'quiz' && message.quizData != null) {
      final quiz = message.quizData!;
      final String question = (quiz['question'] ?? message.content).toString();
      final List<dynamic> options =
          (quiz['options'] as List<dynamic>?) ?? const [];
      final int correctIndex = (quiz['correctIndex'] as num?)?.toInt() ?? 0;
      final Map<String, dynamic> submissions = quiz['submissions'] is Map
          ? Map<String, dynamic>.from(quiz['submissions'] as Map)
          : {};
      final int? myAnswer = submissions[widget.currentUserId] is int
          ? submissions[widget.currentUserId] as int
          : int.tryParse(submissions[widget.currentUserId]?.toString() ?? '');

      return Container(
        key: ValueKey('quiz_${message.messageId}'),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purple.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.quiz_rounded, color: Colors.purple, size: 18),
                SizedBox(width: 6),
                Text(
                  "CLASS MCQ QUIZ",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              question,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(options.length, (i) {
              final bool hasAnswered = myAnswer != null || _isViewerTeacher;
              final bool isCorrectOption = i == correctIndex;
              final bool isMySelected = myAnswer == i;

              Color borderColor = Colors.grey.shade300;
              Color bgColor = const Color(0xFFF8FAFC);
              if (hasAnswered) {
                if (isCorrectOption) {
                  borderColor = Colors.green;
                  bgColor = Colors.green.shade50;
                } else if (isMySelected && !isCorrectOption) {
                  borderColor = Colors.redAccent;
                  bgColor = Colors.red.shade50;
                }
              }

              final optionBox = Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        options[i].toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (hasAnswered && isCorrectOption)
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                    if (hasAnswered && isMySelected && !isCorrectOption)
                      const Icon(Icons.cancel,
                          color: Colors.redAccent, size: 18),
                  ],
                ),
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: (myAnswer != null || _isStudentMuted)
                    ? optionBox
                    : GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          _groupService.submitQuizAnswer(
                            groupId: widget.groupId,
                            messageId: message.messageId,
                            userId: widget.currentUserId,
                            selectedOptionIndex: i,
                          );
                        },
                        child: optionBox,
                      ),
              );
            }),
            Text(
              "${submissions.length} student response${submissions.length == 1 ? '' : 's'}",
              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPrivacySafeMessageHeader(MessageModel message, bool isMe) {
    final String visibleName = message.getVisibleSenderName(
      currentUserId: widget.currentUserId,
      isViewerTeacherOfGroup: _isViewerTeacher,
    );
    final bool isTeacherMsg = message.senderRole == 'teacher' ||
        message.senderId == _currentGroup?.createdBy;
    final String category = message.messageCategory;

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 0 : 12,
        right: isMe ? 12 : 0,
        top: 4,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            GestureDetector(
              onTap: () {
                if (_isViewerTeacher && !isTeacherMsg) {
                  _showStudentModerationDialog(
                    studentId: message.senderId,
                    studentName: visibleName,
                  );
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    visibleName,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isTeacherMsg
                          ? Colors.blueAccent
                          : Colors.blueGrey.shade700,
                    ),
                  ),
                  if (isTeacherMsg &&
                      (message.isSenderVerified ||
                          (_currentGroup?.isTeacherVerified ?? false))) ...[
                    const SizedBox(width: 3),
                    const Icon(Icons.verified,
                        color: Colors.blueAccent, size: 13),
                  ],
                  if (isTeacherMsg &&
                      (message.hasSenderGoldenBadge ||
                          (_currentGroup?.hasGoldenBadge ?? false))) ...[
                    const SizedBox(width: 3),
                    const Icon(Icons.workspace_premium,
                        color: Colors.amber, size: 14),
                  ],
                  if (_isViewerTeacher && !isTeacherMsg) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.admin_panel_settings_outlined,
                        size: 12, color: Colors.grey),
                  ],
                ],
              ),
            ),
          if (category.isNotEmpty && category != 'general') ...[
            if (!isMe) const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                category.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomComposerOrRestrictionBar() {
    if (_currentGroup != null && _currentGroup!.isDismissed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: Colors.red.shade50,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_rounded, color: Colors.redAccent, size: 18),
            SizedBox(width: 8),
            Text(
              "This group has been dismissed by the teacher.",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      );
    }

    if (_isStudentMuted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: AbsorbPointer(
                  absorbing: true,
                  child: TextField(
                    enabled: false,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: "Muted by teacher",
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

    if (_isPostingRestrictedToAdmin) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: const SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.campaign_outlined, color: Colors.blueGrey, size: 19),
              SizedBox(width: 8),
              Text(
                "Only the teacher can send messages in this group",
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
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
              color: const Color(0xFF0F172A),
              alignment: Alignment.center,
              child: _isDragHoveringInput
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: _isDragHoveringInput
                        ? Border.all(color: Colors.blueAccent, width: 2.2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: _isDragHoveringInput
                            ? Colors.blueAccent.withOpacity(0.28)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: _isDragHoveringInput ? 18 : 15,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _openAcademicComposerSheet,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border:
                                        Border.all(color: Colors.blue.shade100),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.school_rounded,
                                        size: 15,
                                        color: Colors.blueAccent,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _isViewerTeacher
                                            ? "Post Homework / Poll / Quiz / Notice"
                                            : "Ask Academic Doubt",
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _openAiStudyAssistantSheet,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.amber.shade200),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        "AI Study Assistant",
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.brown,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ChatInputBar(
                        chatRoomId: widget.groupId,
                        senderId: widget.currentUserId,
                        receiverId: 'group',
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
                            widget.groupId,
                            widget.currentUserId,
                            isTyping,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgProvider = _buildBackgroundProvider();
    final group = _currentGroup;
    final String displayGroupName =
        group?.name.isNotEmpty == true ? group!.name : widget.groupName;
    final int studentCount = group?.studentCount ?? 0;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          _clearMessageSelection();
        } else if (didPop) {
          _chatService.markGroupMessagesAsSeen(
              widget.groupId, widget.currentUserId);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () {
              if (_isSelectionMode) {
                _clearMessageSelection();
              } else {
                _chatService.markGroupMessagesAsSeen(
                    widget.groupId, widget.currentUserId);
                Navigator.pop(context);
              }
            },
          ),
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: "Search messages in group...",
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                  ),
                )
              : InkWell(
                  onTap: _openGroupInfoPage,
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 19,
                          backgroundColor: const Color(0xFF1E293B),
                          backgroundImage:
                              (group != null && group.imageUrl.isNotEmpty)
                                  ? NetworkImage(group.imageUrl)
                                  : null,
                          child: (group == null || group.imageUrl.isEmpty)
                              ? const Icon(Icons.groups_rounded,
                                  color: Colors.blueAccent, size: 22)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayGroupName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (group?.isTeacherVerified == true) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified,
                                      color: Colors.blueAccent, size: 15),
                                ],
                                if (group?.hasGoldenBadge == true) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.workspace_premium,
                                      color: Colors.amber, size: 16),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$studentCount Students • Tap for Group Info',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.72),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.amber, size: 21),
              tooltip: "AI Study Assistant",
              onPressed: _openAiStudyAssistantSheet,
            ),
            IconButton(
              icon: Icon(
                _isSearching ? Icons.close_rounded : Icons.search_rounded,
                color: Colors.white,
                size: 21,
              ),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = '';
                  }
                });
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: Colors.white, size: 20),
              onSelected: (value) async {
                if (value == 'info') {
                  _openGroupInfoPage();
                } else if (value == 'media') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MediaDocsLinksScreen(
                        chatOrGroupId: widget.groupId,
                        title: displayGroupName,
                        currentUserId: widget.currentUserId,
                        isGroup: true,
                        isViewerTeacherOfGroup: _isViewerTeacher,
                      ),
                    ),
                  );
                } else if (value == 'academic') {
                  _openAcademicComposerSheet();
                } else if (value == 'ai') {
                  _openAiStudyAssistantSheet();
                } else if (value == 'export') {
                  final transcript = await _chatService.exportChatTranscript(
                    chatOrGroupId: widget.groupId,
                    isGroup: true,
                    currentUserId: widget.currentUserId,
                    isViewerTeacherOfGroup: _isViewerTeacher,
                  );
                  if (transcript.isNotEmpty) {
                    await Clipboard.setData(ClipboardData(text: transcript));
                    _showSnackBar("Chat transcript copied to clipboard!");
                  }
                } else if (value == 'dismiss') {
                  _confirmDismissGroup();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'info',
                  child: Text('Group Information & Admin'),
                ),
                const PopupMenuItem(
                  value: 'media',
                  child: Text('Media, Study Docs & Links'),
                ),
                PopupMenuItem(
                  value: 'academic',
                  child: Text(_isViewerTeacher
                      ? 'Academic Studio (Homework/Poll/Quiz)'
                      : 'Ask an Academic Doubt'),
                ),
                const PopupMenuItem(
                  value: 'ai',
                  child: Text('AI Study Assistant & Summary'),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Text('Export Chat Copy'),
                ),
                if (_isViewerTeacher)
                  const PopupMenuItem(
                    value: 'dismiss',
                    child: Text(
                      'Dismiss Group Permanently',
                      style: TextStyle(
                          color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            image: bgProvider != null
                ? DecorationImage(
                    image: bgProvider,
                    fit: BoxFit.cover,
                    opacity: 0.03,
                    onError: (_, __) {},
                  )
                : null,
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  _buildCategoryFilterBar(),
                  Expanded(
                    child: StreamBuilder<List<MessageModel>>(
                      stream: _messagesStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text(
                              'Failed to load group messages.',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w500),
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            _latestMessages.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: Colors.blueAccent),
                          );
                        }

                        final rawMessages = (snapshot.data ?? _latestMessages)
                            .where((m) => !m.deletedForUsers
                                .contains(widget.currentUserId))
                            .toList();
                        _latestMessages = rawMessages;

                        final messages = _searchQuery.isEmpty
                            ? rawMessages
                            : rawMessages
                                .where((m) => m.content
                                    .toLowerCase()
                                    .contains(_searchQuery))
                                .toList();

                        if (messages.isEmpty) {
                          return Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Text(
                                _selectedCategory == 'all'
                                    ? 'Welcome to FYBTT Secure Group Chat'
                                    : 'No messages in this category yet',
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            _buildPinnedMessageBanner(rawMessages),
                            Expanded(
                              child: ListView.builder(
                                key: PageStorageKey<String>(
                                    'group_chat_${widget.groupId}_$_selectedCategory'),
                                controller: _scrollController,
                                reverse: true,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: EdgeInsets.only(
                                  left: 14,
                                  right: 14,
                                  top: _showTopActionBar ? 68 : 12,
                                  bottom: 12,
                                ),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final rawMsg = messages[index];
                                  final message =
                                      _resolveMessageWithReplyText(rawMsg);
                                  final bool isMe =
                                      message.senderId == widget.currentUserId;
                                  final bool isSelected = _selectedMessageIds
                                      .contains(message.messageId);

                                  final bool showDateHeader =
                                      index == messages.length - 1 ||
                                          !_isSameCalendarDay(
                                            message.timestamp,
                                            messages[index + 1].timestamp,
                                          );

                                  final bool showUnreadBanner =
                                      _initialUnreadCount > 0 &&
                                          index == _initialUnreadCount - 1;

                                  return Column(
                                    key: ValueKey('grp_msg_${message.messageId}'),
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
                                              color: Colors.blueGrey
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _formatDateHeader(
                                                  message.timestamp),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueGrey,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (showUnreadBanner)
                                        Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            "$_initialUnreadCount Unread Messages",
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueAccent,
                                            ),
                                          ),
                                        ),
                                      _buildPrivacySafeMessageHeader(
                                          message, isMe),
                                      if (message.type == 'poll' ||
                                          message.type == 'quiz')
                                        _buildInteractivePollOrQuizCard(
                                            message, isMe)
                                      else
                                        GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onTap: _isSelectionMode
                                              ? () => _toggleMessageSelection(
                                                  message)
                                              : null,
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 180),
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.blueAccent
                                                      .withOpacity(0.14)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: isMe
                                                  ? MainAxisAlignment.end
                                                  : MainAxisAlignment.start,
                                              children: [
                                                if (_isSelectionMode && !isMe)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            right: 6),
                                                    child: Icon(
                                                      isSelected
                                                          ? Icons
                                                              .check_circle_rounded
                                                          : Icons
                                                              .radio_button_unchecked_rounded,
                                                      color: isSelected
                                                          ? Colors.blueAccent
                                                          : Colors
                                                              .grey.shade400,
                                                      size: 20,
                                                    ),
                                                  ),
                                                Flexible(
                                                  fit: FlexFit.loose,
                                                  child: LongPressDraggable<
                                                      MessageModel>(
                                                    delay: const Duration(
                                                        milliseconds: 500),
                                                    data: message,
                                                    onDragStarted: () {
                                                      HapticFeedback
                                                          .mediumImpact();
                                                      setState(() {
                                                        _didDropOnTarget =
                                                            false;
                                                        _isDraggingMessage =
                                                            true;
                                                        _draggedMessage =
                                                            message;
                                                      });
                                                    },
                                                    onDragUpdate: (details) {
                                                      if (!_canCurrentUserReply) {
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
                                                              150;
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
                                                          _selectedMessageIds
                                                              .add(message
                                                                  .messageId);
                                                        }
                                                        _draggedMessage = null;
                                                        _hoveredTopAction =
                                                            null;
                                                        _isDragHoveringInput =
                                                            false;
                                                      });
                                                    },
                                                    feedback: Material(
                                                      color: Colors.transparent,
                                                      child: Transform.scale(
                                                        scale: 1.05,
                                                        child: IgnorePointer(
                                                          child: MessageBubble(
                                                            message: message,
                                                            isMe: isMe,
                                                            chatRoomId:
                                                                widget.groupId,
                                                            currentUserId: widget
                                                                .currentUserId,
                                                            onReplyPressed:
                                                                (_) {},
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
                                                              widget.groupId,
                                                          currentUserId:
                                                              widget.currentUserId,
                                                          onReplyPressed:
                                                              (_) {},
                                                        ),
                                                      ),
                                                    ),
                                                    child: MessageBubble(
                                                      message: message,
                                                      isMe: isMe,
                                                      chatRoomId:
                                                          widget.groupId,
                                                      currentUserId:
                                                          widget.currentUserId,
                                                      onReplyPressed:
                                                          (repliedMsg) {
                                                        _triggerReply(
                                                            repliedMsg);
                                                      },
                                                      onReplyPreviewTap: () =>
                                                          _scrollToOriginalMessage(
                                                              message
                                                                  .replyToMessageId),
                                                    ),
                                                  ),
                                                ),
                                                if (_isSelectionMode && isMe)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 6),
                                                    child: Icon(
                                                      isSelected
                                                          ? Icons
                                                              .check_circle_rounded
                                                          : Icons
                                                              .radio_button_unchecked_rounded,
                                                      color: isSelected
                                                          ? Colors.blueAccent
                                                          : Colors
                                                              .grey.shade400,
                                                      size: 20,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  _buildBottomComposerOrRestrictionBar(),
                ],
              ),
              if (_showTopActionBar) _buildTopActionToolbar(),
              ValueListenableBuilder<bool>(
                valueListenable: _showScrollToBottomBtnNotifier,
                builder: (context, showBtn, _) {
                  if (!showBtn) return const SizedBox.shrink();
                  return Positioned(
                    right: 16,
                    bottom: 86,
                    child: FloatingActionButton.small(
                      backgroundColor: const Color(0xFF0F172A),
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
