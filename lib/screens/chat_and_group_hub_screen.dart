import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import '../utils/chat_colors.dart';
import 'group/create_group_screen.dart';
import 'group/group_list_screen.dart';
import 'group/invitation_list_screen.dart';

class ChatAndGroupHubScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final bool isTeacher;
  final int initialTabIndex;
  final void Function(
    String chatId,
    String otherUserId,
    String otherUserName,
    String otherUserImage,
    bool isOtherUserTeacher,
  )? onOpenPrivateChat;

  const ChatAndGroupHubScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    this.isTeacher = false,
    this.initialTabIndex = 0,
    this.onOpenPrivateChat,
  });

  @override
  State<ChatAndGroupHubScreen> createState() => _ChatAndGroupHubScreenState();
}

class _ChatAndGroupHubScreenState extends State<ChatAndGroupHubScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();

  late TabController _tabController;
  String _chatSearchQuery = '';
  String _selectedChatFilter = 'all';
  bool _isTeacherRole = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isTeacherRole = widget.isTeacher;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _verifyUserRoleAndOnlineState();
  }

  Future<void> _verifyUserRoleAndOnlineState() async {
    if (widget.currentUserId.trim().isEmpty) return;
    try {
      final teacherDoc = await _firestore
          .collection('teachers')
          .doc(widget.currentUserId)
          .get();
      if (teacherDoc.exists) {
        _isTeacherRole = true;
      } else {
        final userDoc = await _firestore
            .collection('users')
            .doc(widget.currentUserId)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final role =
              (userDoc.data()!['role'] ?? userDoc.data()!['type'] ?? '')
                  .toString()
                  .toLowerCase();
          if (role == 'teacher') {
            _isTeacherRole = true;
          }
        }
      }
      if (mounted) setState(() {});
      await _chatService.updateOnlineStatus(
        widget.currentUserId,
        true,
        _isTeacherRole,
      );
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.currentUserId.trim().isEmpty) return;
    if (state == AppLifecycleState.resumed) {
      _chatService.updateOnlineStatus(
          widget.currentUserId, true, _isTeacherRole);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _chatService.updateOnlineStatus(
          widget.currentUserId, false, _isTeacherRole);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  String _formatChatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final DateTime date = timestamp.toDate();
    final DateTime now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return DateFormat.jm().format(date);
    }
    final DateTime yesterday = now.subtract(const Duration(days: 1));
    if (date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year) {
      return 'Yesterday';
    }
    return DateFormat('dd/MM/yy').format(date);
  }

  String _formatLastSeen(Timestamp? timestamp) {
    if (timestamp == null) return 'Offline';
    final DateTime date = timestamp.toDate();
    final DateTime now = DateTime.now();
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Last seen today at ${DateFormat.jm().format(date)}';
    }
    return 'Last seen ${DateFormat('dd MMM').format(date)}';
  }

  int _extractUnreadCount(Map<String, dynamic> chatData) {
    final String uid = widget.currentUserId;
    if (chatData.containsKey('unreadCount_$uid')) {
      return (chatData['unreadCount_$uid'] as num?)?.toInt() ?? 0;
    }
    if (chatData['unreadFor'] == uid) {
      return (chatData['unreadCount'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  void _showPrivateChatActionsSheet({
    required String chatId,
    required String otherUserName,
    required bool isPinned,
    required bool isMuted,
    required bool isArchived,
    required bool isBlocked,
  }) {
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
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  otherUserName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  color: ChatColors.primaryApp,
                ),
                title: Text(isPinned ? 'Unpin Chat' : 'Pin Chat'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _chatService.togglePinChat(
                    chatId,
                    widget.currentUserId,
                    !isPinned,
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  isMuted
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  color: ChatColors.primaryApp,
                ),
                title: Text(
                    isMuted ? 'Unmute Notifications' : 'Mute Notifications'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _chatService.toggleMuteChat(
                    chatId,
                    widget.currentUserId,
                    !isMuted,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.mark_chat_unread_outlined,
                  color: ChatColors.primaryApp,
                ),
                title: const Text('Mark as Unread'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _chatService.markChatAsUnread(
                    chatId,
                    widget.currentUserId,
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  color: ChatColors.primaryApp,
                ),
                title: Text(isArchived ? 'Unarchive Chat' : 'Archive Chat'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _chatService.toggleArchiveChat(
                    chatId,
                    widget.currentUserId,
                    !isArchived,
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.block_rounded,
                  color: isBlocked ? Colors.orange : Colors.redAccent,
                ),
                title: Text(
                  isBlocked ? 'Unblock User' : 'Block User',
                  style: TextStyle(
                    color: isBlocked ? Colors.orange : Colors.redAccent,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _chatService.toggleBlockChat(
                    chatId,
                    widget.currentUserId,
                    !isBlocked,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNetworkStyleTabSwitcher() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: [
            Tab(
              child: StreamBuilder<int>(
                stream: _chatService
                    .getTotalUnreadChatsCountStream(widget.currentUserId),
                builder: (context, snapshot) {
                  final int unread = snapshot.data ?? 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      const SizedBox(width: 7),
                      const Text('Chats'),
                      if (unread > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _tabController.index == 0
                                ? Colors.white
                                : Colors.blueAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: TextStyle(
                              color: _tabController.index == 0
                                  ? Colors.blueAccent
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            Tab(
              child: StreamBuilder<int>(
                stream: _chatService
                    .getTotalUnreadGroupsCountStream(widget.currentUserId),
                builder: (context, snapshot) {
                  final int unread = snapshot.data ?? 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.groups_rounded, size: 20),
                      const SizedBox(width: 7),
                      const Text('Groups'),
                      if (unread > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _tabController.index == 1
                                ? Colors.white
                                : Colors.blueAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: TextStyle(
                              color: _tabController.index == 1
                                  ? Colors.blueAccent
                                  : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'All Chats'},
      {'key': 'unread', 'label': 'Unread'},
      {'key': 'pinned', 'label': 'Pinned'},
      {'key': 'archived', 'label': 'Archived'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final bool isSelected = _selectedChatFilter == f['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f['label']!),
                selected: isSelected,
                selectedColor: ChatColors.primaryApp.withOpacity(0.15),
                backgroundColor: const Color(0xFFF0F2F5),
                labelStyle: TextStyle(
                  color: isSelected ? ChatColors.primaryApp : Colors.black54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? ChatColors.primaryApp
                        : Colors.transparent,
                  ),
                ),
                onSelected: (_) {
                  setState(() => _selectedChatFilter = f['key']!);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPrivateChatsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _chatSearchQuery = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search teachers, students or messages...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14.5),
                prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        _buildChatFilterChips(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _chatService.getUserChatsStream(widget.currentUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(color: ChatColors.primaryApp),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyChatsState();
              }

              final allDocs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['isGroup'] == true) return false;

                final List<dynamic> archivedBy =
                    (data['archivedBy'] as List<dynamic>?) ?? const [];
                final bool isArchived =
                    archivedBy.contains(widget.currentUserId);

                if (_selectedChatFilter == 'archived' && !isArchived) {
                  return false;
                }
                if (_selectedChatFilter != 'archived' && isArchived) {
                  return false;
                }

                final List<dynamic> pinnedBy =
                    (data['pinnedBy'] as List<dynamic>?) ?? const [];
                final bool isPinned = pinnedBy.contains(widget.currentUserId);
                if (_selectedChatFilter == 'pinned' && !isPinned) {
                  return false;
                }

                final int unreadCount = _extractUnreadCount(data);
                if (_selectedChatFilter == 'unread' && unreadCount <= 0) {
                  return false;
                }

                if (_chatSearchQuery.isEmpty) return true;

                final String teacherName =
                    (data['teacherName'] ?? '').toString().toLowerCase();
                final String studentName =
                    (data['studentName'] ?? '').toString().toLowerCase();
                final String lastMsg =
                    (data['lastMessage'] ?? '').toString().toLowerCase();

                return teacherName.contains(_chatSearchQuery) ||
                    studentName.contains(_chatSearchQuery) ||
                    lastMsg.contains(_chatSearchQuery);
              }).toList();

              allDocs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;

                final bool aPinned = ((aData['pinnedBy'] as List<dynamic>?) ??
                        const [])
                    .contains(widget.currentUserId);
                final bool bPinned = ((bData['pinnedBy'] as List<dynamic>?) ??
                        const [])
                    .contains(widget.currentUserId);

                if (aPinned && !bPinned) return -1;
                if (!aPinned && bPinned) return 1;

                final Timestamp? aTime = aData['lastMessageTime'] as Timestamp?;
                final Timestamp? bTime = bData['lastMessageTime'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

              if (allDocs.isEmpty) {
                return _buildEmptyChatsState();
              }

              return ListView.separated(
                itemCount: allDocs.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  indent: 78,
                  color: Color(0xFFEEEEEE),
                ),
                itemBuilder: (context, index) {
                  final doc = allDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final String chatId =
                      (data['chatId'] ?? doc.id).toString();

                  final String teacherId =
                      (data['teacherId'] ?? '').toString();
                  final String studentId =
                      (data['studentId'] ?? '').toString();
                  final List<dynamic> participants =
                      (data['participants'] as List<dynamic>?) ?? const [];

                  String otherUserId = '';
                  if (teacherId.isNotEmpty &&
                      teacherId != widget.currentUserId) {
                    otherUserId = teacherId;
                  } else if (studentId.isNotEmpty &&
                      studentId != widget.currentUserId) {
                    otherUserId = studentId;
                  } else {
                    for (final p in participants) {
                      if (p.toString() != widget.currentUserId) {
                        otherUserId = p.toString();
                        break;
                      }
                    }
                  }

                  final bool isOtherUserTeacher =
                      otherUserId.isNotEmpty && otherUserId == teacherId;

                  final String fallbackName = isOtherUserTeacher
                      ? (data['teacherName'] ?? 'Teacher').toString()
                      : (data['studentName'] ?? 'Student').toString();

                  final String fallbackImage = isOtherUserTeacher
                      ? (data['teacherImage'] ?? '').toString()
                      : (data['studentImage'] ?? '').toString();

                  final String lastMessage = (data['lastMessage'] ??
                          data['lastMessageContent'] ??
                          'Start a conversation...')
                      .toString();
                  final Timestamp? lastMessageTime =
                      data['lastMessageTime'] as Timestamp?;
                  final int unreadCount = _extractUnreadCount(data);

                  final bool isPinned =
                      ((data['pinnedBy'] as List<dynamic>?) ?? const [])
                          .contains(widget.currentUserId);
                  final bool isMuted =
                      ((data['mutedBy'] as List<dynamic>?) ?? const [])
                          .contains(widget.currentUserId);
                  final bool isArchived =
                      ((data['archivedBy'] as List<dynamic>?) ?? const [])
                          .contains(widget.currentUserId);
                  final bool isBlocked =
                      ((data['blockedBy'] as List<dynamic>?) ?? const [])
                          .contains(widget.currentUserId);

                  return StreamBuilder<Map<String, dynamic>>(
                    stream: _chatService.getUserStatusStream(
                      otherUserId,
                      isOtherUserTeacher,
                    ),
                    builder: (context, statusSnap) {
                      final statusData = statusSnap.data ?? const {};
                      final bool isOnline = statusData['isOnline'] == true;
                      final Timestamp? lastSeen =
                          statusData['lastSeen'] as Timestamp?;
                      final String resolvedName =
                          (statusData['fullName'] ?? fallbackName).toString();
                      final String resolvedImage =
                          (statusData['profileImageUrl'] ?? fallbackImage)
                              .toString();

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.blue.shade50,
                              backgroundImage: resolvedImage.isNotEmpty
                                  ? NetworkImage(resolvedImage)
                                  : null,
                              child: resolvedImage.isEmpty
                                  ? Text(
                                      resolvedName.isNotEmpty
                                          ? resolvedName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: ChatColors.primaryApp,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? Colors.green
                                      : Colors.grey.shade400,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                resolvedName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (isOtherUserTeacher) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                color: Colors.blueAccent,
                                size: 15,
                              ),
                            ],
                            if (isPinned) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.push_pin_rounded,
                                color: Colors.blueGrey,
                                size: 14,
                              ),
                            ],
                            if (isMuted) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.volume_off_rounded,
                                color: Colors.grey,
                                size: 15,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: StreamBuilder<bool>(
                            stream: _chatService.getTypingStatusStream(
                                chatId, otherUserId),
                            builder: (context, typingSnap) {
                              final bool isTyping = typingSnap.data == true;
                              if (isTyping) {
                                return const Text(
                                  'typing...',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: unreadCount > 0
                                          ? Colors.black87
                                          : Colors.grey.shade600,
                                      fontWeight: unreadCount > 0
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isOnline
                                        ? 'Online'
                                        : _formatLastSeen(lastSeen),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isOnline
                                          ? Colors.green.shade700
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatChatTime(lastMessageTime),
                              style: TextStyle(
                                fontSize: 11,
                                color: unreadCount > 0
                                    ? ChatColors.primaryApp
                                    : Colors.grey,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 5),
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: ChatColors.primaryApp,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onLongPress: () => _showPrivateChatActionsSheet(
                          chatId: chatId,
                          otherUserName: resolvedName,
                          isPinned: isPinned,
                          isMuted: isMuted,
                          isArchived: isArchived,
                          isBlocked: isBlocked,
                        ),
                        onTap: () {
                          _chatService.markAsSeen(
                              chatId, widget.currentUserId);
                          if (widget.onOpenPrivateChat != null) {
                            widget.onOpenPrivateChat!(
                              chatId,
                              otherUserId,
                              resolvedName,
                              resolvedImage,
                              isOtherUserTeacher,
                            );
                          }
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChatsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            _selectedChatFilter == 'archived'
                ? 'No archived chats'
                : 'No private chats found',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Switch to the Groups tab to view batch discussions.',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13,
            ),
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
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          'Messages & Batches',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(widget.currentUserId)
                .collection('group_invites')
                .snapshots(),
            builder: (context, snapshot) {
              final int inviteCount =
                  snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.mail_outline_rounded,
                        color: Colors.white),
                    tooltip: 'Group Invitations',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvitationListScreen(
                            currentUserId: widget.currentUserId,
                          ),
                        ),
                      );
                    },
                  ),
                  if (inviteCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$inviteCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (_isTeacherRole)
            IconButton(
              icon: const Icon(Icons.group_add_rounded, color: Colors.white),
              tooltip: 'Create Teacher Group',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreateGroupScreen(teacherId: widget.currentUserId),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildNetworkStyleTabSwitcher(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPrivateChatsTab(),
                GroupListScreen(
                  currentUserId: widget.currentUserId,
                  currentUserName: widget.currentUserName,
                  isEmbedded: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
