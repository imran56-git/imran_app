import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'group/create_group_screen.dart';
import 'group/group_chat_screen.dart';
import 'group/group_list_screen.dart';
import 'group/invitation_list_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String currentUserId;
  final bool isTeacher;

  const ChatListScreen({
    super.key,
    required this.currentUserId,
    required this.isTeacher,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin,
        SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  late final Stream<QuerySnapshot> _chatsStream;
  late final Stream<int> _unreadChatsCountStream;
  late final Stream<int> _unreadGroupsCountStream;
  QuerySnapshot? _lastChatsSnapshot;

  final Map<String, Stream<Map<String, dynamic>>> _userStatusStreams = {};
  final Map<String, Map<String, dynamic>> _userProfileCache = {};
  final Map<String, Stream<bool>> _typingStreams = {};

  String _searchText = '';
  String _currentUserName = 'User';

  final Set<String> _selectedChatDocIds = {};

  bool get _isSelectionMode => _selectedChatDocIds.isNotEmpty;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _chatsStream = _chatService.getUserChatsStream(widget.currentUserId);
    _unreadChatsCountStream =
        _chatService.getTotalUnreadChatsCountStream(widget.currentUserId);
    _unreadGroupsCountStream =
        _chatService.getTotalUnreadGroupsCountStream(widget.currentUserId);

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _isSelectionMode) {
        _clearSelection();
      }
    });

    _loadCurrentUserName();
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (next != _searchText && mounted) {
        setState(() {
          _searchText = next;
        });
      }
    });
  }

  Stream<Map<String, dynamic>> _getCachedUserStatusStream(String userId) {
    return _userStatusStreams.putIfAbsent(
      userId,
      () => _chatService.getUserStatusStream(userId, !widget.isTeacher),
    );
  }

  Stream<bool> _getCachedTypingStream(String chatDocId, String receiverId) {
    final key = '${chatDocId}_$receiverId';
    return _typingStreams.putIfAbsent(
      key,
      () => _chatService.getTypingStatusStream(chatDocId, receiverId),
    );
  }

  Future<void> _loadCurrentUserName() async {
    try {
      final data = await _chatService.getUserProfile(
        widget.currentUserId,
        widget.isTeacher,
      );
      if (data != null && mounted) {
        setState(() {
          _currentUserName = (data['fullName'] ??
                  data['name'] ??
                  data['displayName'] ??
                  'User')
              .toString();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String docId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedChatDocIds.contains(docId)) {
        _selectedChatDocIds.remove(docId);
      } else {
        _selectedChatDocIds.add(docId);
      }
    });
  }

  void _clearSelection() {
    if (_selectedChatDocIds.isEmpty) return;
    setState(() {
      _selectedChatDocIds.clear();
    });
  }

  void _confirmDeleteSelected() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFDC2626),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Selected Chats?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17.5,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedChatDocIds.length} selected conversation(s)? This action will remove them from your chat list.',
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
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final idsToDelete = List<String>.from(_selectedChatDocIds);
              _clearSelection();

              for (final String docId in idsToDelete) {
                try {
                  final chatRef =
                      FirebaseFirestore.instance.collection('chats').doc(docId);
                  final messagesSnap =
                      await chatRef.collection('messages').get();
                  final batch = FirebaseFirestore.instance.batch();
                  for (final mDoc in messagesSnap.docs) {
                    batch.delete(mDoc.reference);
                  }
                  batch.delete(chatRef);
                  await batch.commit();
                } catch (_) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(docId)
                        .set({
                      'deletedBy':
                          FieldValue.arrayUnion([widget.currentUserId]),
                      'lastMessage': '',
                      'unreadCount_${widget.currentUserId}': 0,
                    }, SetOptions(merge: true));
                  } catch (_) {}
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    if (isToday) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $amPm';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _openChat({
    required Map<String, dynamic> chatData,
    required String chatDocId,
    required String receiverName,
    required String receiverId,
    required String receiverImage,
  }) {
    final bool isGroup = chatData['isGroup'] == true;

    if (isGroup) {
      final String groupName =
          (chatData['groupName'] ?? 'Group Chat').toString();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            groupId: chatDocId,
            groupName: groupName,
            currentUserId: widget.currentUserId,
            currentUserName: _currentUserName,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatRoomId: chatDocId,
            receiverId: receiverId,
            receiverName: receiverName,
            receiverProfilePic: receiverImage,
            currentUserId: widget.currentUserId,
            isTeacher: widget.isTeacher,
          ),
        ),
      );
    }
  }

  bool _matchesSearch(Map<String, dynamic> chatData, String otherUserName) {
    if (_searchText.isEmpty) return true;
    final name = otherUserName.toLowerCase();
    final lastMessage =
        (chatData['lastMessage'] ?? '').toString().toLowerCase();
    return name.contains(_searchText) || lastMessage.contains(_searchText);
  }

  Widget _buildAdvancedSegmentedTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E4C7A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E4C7A).withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          tabs: [
            Tab(
              child: StreamBuilder<int>(
                stream: _unreadChatsCountStream,
                builder: (context, snapshot) {
                  final int count = snapshot.data ?? 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.forum_rounded, size: 16),
                      const SizedBox(width: 7),
                      const Text('Chats'),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
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
                stream: _unreadGroupsCountStream,
                builder: (context, snapshot) {
                  final int count = snapshot.data ?? 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.groups_rounded, size: 18),
                      const SizedBox(width: 7),
                      const Text('Groups'),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
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

  Widget _buildPrivateChatsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatsStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _lastChatsSnapshot = snapshot.data;
        }

        final activeData = snapshot.data ?? _lastChatsSnapshot;

        if (activeData == null &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1E4C7A)),
          );
        }
        if (snapshot.hasError && activeData == null) {
          return const Center(
            child: Text(
              'Failed to load chats.',
              style: TextStyle(fontSize: 14, color: Colors.red),
            ),
          );
        }
        if (activeData == null || activeData.docs.isEmpty) {
          return _buildEmptyState();
        }

        final rawChatDocs = activeData.docs;
        final Map<String, DocumentSnapshot> uniqueChatsMap = {};

        for (var doc in rawChatDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final List<dynamic> deletedBy =
              (data['deletedBy'] as List<dynamic>?) ?? const [];
          if (deletedBy.contains(widget.currentUserId)) continue;

          final bool isGroup = data['isGroup'] == true;
          if (isGroup) continue;

          final bool isOfficial = data['isOfficial'] == true ||
              doc.id.startsWith('official_desk_');

          if (isOfficial) {
            uniqueChatsMap['official_desk'] = doc;
          } else {
            final List<dynamic> participants = data['participants'] ?? [];
            final List<String> participantsList =
                List<String>.from(participants);
            participantsList.remove(widget.currentUserId);

            if (participantsList.isNotEmpty) {
              final String otherUserId = participantsList.first;

              if (!uniqueChatsMap.containsKey(otherUserId)) {
                uniqueChatsMap[otherUserId] = doc;
              } else {
                final existingData =
                    uniqueChatsMap[otherUserId]!.data() as Map<String, dynamic>;
                final existingTime =
                    existingData['lastMessageTime'] as Timestamp?;
                final currentTime = data['lastMessageTime'] as Timestamp?;

                if (currentTime != null &&
                    (existingTime == null ||
                        currentTime.compareTo(existingTime) > 0)) {
                  uniqueChatsMap[otherUserId] = doc;
                }
              }
            }
          }
        }

        final chatDocs = uniqueChatsMap.values.toList();

        chatDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aIsOfficial = aData['isOfficial'] == true ||
              a.id.startsWith('official_desk_');
          final bIsOfficial = bData['isOfficial'] == true ||
              b.id.startsWith('official_desk_');

          if (aIsOfficial && !bIsOfficial) return -1;
          if (!aIsOfficial && bIsOfficial) return 1;

          final aTime = aData['lastMessageTime'] as Timestamp?;
          final bTime = bData['lastMessageTime'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (chatDocs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          key: const PageStorageKey<String>('private_chats_list_view'),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
          physics: const BouncingScrollPhysics(),
          itemCount: chatDocs.length,
          itemBuilder: (context, index) {
            final doc = chatDocs[index];
            final chatData = doc.data() as Map<String, dynamic>;
            final bool isOfficial = chatData['isOfficial'] == true ||
                doc.id.startsWith('official_desk_');

            final String lastMessage =
                (chatData['lastMessage'] ?? '').toString();
            final Timestamp? lastTime =
                chatData['lastMessageTime'] as Timestamp?;
            final bool isSelected = _selectedChatDocIds.contains(doc.id);

            final String lastSenderId =
                (chatData['lastSenderId'] ?? chatData['senderId'] ?? '')
                    .toString();
            int unreadCount = 0;

            if (lastSenderId != widget.currentUserId) {
              if (chatData
                  .containsKey('unreadCount_${widget.currentUserId}')) {
                unreadCount =
                    chatData['unreadCount_${widget.currentUserId}'] ?? 0;
              } else {
                unreadCount = chatData['unreadCount'] ?? 0;
              }
            }

            if (isOfficial) {
              const String officialName = 'FYBTT official';
              if (!_matchesSearch(chatData, officialName)) {
                return const SizedBox.shrink();
              }

              return _ChatCard(
                key: ValueKey('official_${doc.id}'),
                name: officialName,
                lastMessage: lastMessage.isEmpty
                    ? 'Official Communication Desk'
                    : lastMessage,
                timeText: _formatTime(lastTime),
                unreadCount: unreadCount,
                imageUrl: '',
                isOnline: true,
                isGroup: false,
                isOfficial: true,
                isVerified: true,
                isSelected: isSelected,
                onLongPress: () => _toggleSelection(doc.id),
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleSelection(doc.id);
                  } else {
                    _openChat(
                      chatData: chatData,
                      chatDocId: doc.id,
                      receiverName: officialName,
                      receiverId: 'OFFICIAL_FYBTT_DESK',
                      receiverImage: 'assets/images/app_logo.png',
                    );
                  }
                },
              );
            }

            final List<dynamic> participants = chatData['participants'] ?? [];
            final List<String> participantsList =
                List<String>.from(participants);
            participantsList.remove(widget.currentUserId);
            if (participantsList.isEmpty) {
              return const SizedBox.shrink();
            }
            final String receiverId = participantsList.first;

            final String fallbackName = (chatData['receiverName'] ??
                    chatData['teacherName'] ??
                    chatData['studentName'] ??
                    'User')
                .toString();

            return StreamBuilder<Map<String, dynamic>>(
              stream: _getCachedUserStatusStream(receiverId),
              initialData: _userProfileCache[receiverId],
              builder: (context, userSnapshot) {
                if (userSnapshot.hasData && userSnapshot.data != null) {
                  _userProfileCache[receiverId] = userSnapshot.data!;
                }
                final mapData = _userProfileCache[receiverId];

                String finalName = fallbackName;
                String finalImageUrl = '';
                bool isOnline = false;
                bool isVerifiedUser = false;

                if (mapData != null) {
                  final extractedName = (mapData['fullName'] ??
                          mapData['name'] ??
                          mapData['displayName'] ??
                          mapData['teacherName'] ??
                          mapData['studentName'])
                      ?.toString();

                  if (extractedName != null && extractedName.isNotEmpty) {
                    finalName = extractedName;
                  }

                  finalImageUrl = (mapData['profileImageUrl'] ??
                          mapData['profilePic'] ??
                          mapData['profileUrl'] ??
                          '')
                      .toString();
                  isOnline = mapData['isOnline'] == true;
                  isVerifiedUser = mapData['isVerified'] == true ||
                      mapData['status'] == 'approved';
                }

                if (!_matchesSearch(chatData, finalName)) {
                  return const SizedBox.shrink();
                }

                return StreamBuilder<bool>(
                  stream: _getCachedTypingStream(doc.id, receiverId),
                  initialData: false,
                  builder: (context, typingSnap) {
                    final bool isTyping = typingSnap.data == true;
                    return _ChatCard(
                      key: ValueKey('chat_${doc.id}'),
                      name: finalName,
                      lastMessage: isTyping ? 'typing a message...' : lastMessage,
                      isTyping: isTyping,
                      timeText: _formatTime(lastTime),
                      unreadCount: unreadCount,
                      imageUrl: finalImageUrl,
                      isOnline: isOnline,
                      isGroup: false,
                      isOfficial: false,
                      isVerified: isVerifiedUser,
                      isSelected: isSelected,
                      onLongPress: () => _toggleSelection(doc.id),
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(doc.id);
                        } else {
                          _openChat(
                            chatData: chatData,
                            chatDocId: doc.id,
                            receiverName: finalName,
                            receiverId: receiverId,
                            receiverImage: finalImageUrl,
                          );
                        }
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          _clearSelection();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            _buildTopHeader(),
            _buildAdvancedSegmentedTabs(),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  RepaintBoundary(
                    child: _buildPrivateChatsList(),
                  ),
                  RepaintBoundary(
                    child: GroupListScreen(
                      currentUserId: widget.currentUserId,
                      currentUserName: _currentUserName,
                      isEmbedded: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey<bool>(_isSelectionMode),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          gradient: _isSelectionMode
              ? const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E3A8A),
                    Color(0xFF1E4C7A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(26),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _isSelectionMode
            ? Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _clearSelection,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_selectedChatDocIds.length} Selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _confirmDeleteSelected,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withOpacity(0.5),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFFCA5A5),
                            size: 18,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (value) {
                      if (value == 'clear') _clearSelection();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            Icon(Icons.clear_all_rounded,
                                color: Color(0xFF0F172A)),
                            SizedBox(width: 8),
                            Text(
                              'Deselect All',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'FYBTT Chats',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.22),
                                    ),
                                  ),
                                  child: Text(
                                    widget.isTeacher ? 'Educator Hub' : 'Student Hub',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.isTeacher
                                  ? 'Direct messages & academic batch groups'
                                  : 'Connect with your teachers & study batches',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.74),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!widget.isTeacher)
                            _buildHeaderActionBtn(
                              icon: Icons.mail_outline_rounded,
                              label: 'Invites',
                              onTap: () {
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
                          if (widget.isTeacher)
                            _buildHeaderActionBtn(
                              icon: Icons.group_add_rounded,
                              label: 'New Group',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CreateGroupScreen(
                                      teacherId: widget.currentUserId,
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSearchBar(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.24),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.22),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: 'Search by student, teacher or message...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Colors.white70,
            size: 20,
          ),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.cancel_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  onPressed: _searchController.clear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E4C7A).withOpacity(0.12),
                    const Color(0xFF2563EB).withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 40,
                color: Color(0xFF1E4C7A),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No active conversations yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isTeacher
                  ? 'Your connected students and private academic discussions will appear here.'
                  : 'Connect with verified teachers to start one-on-one academic chats.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  final String name;
  final String lastMessage;
  final bool isTyping;
  final String timeText;
  final int unreadCount;
  final String imageUrl;
  final bool isOnline;
  final bool isGroup;
  final bool isOfficial;
  final bool isVerified;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatCard({
    super.key,
    required this.name,
    required this.lastMessage,
    this.isTyping = false,
    required this.timeText,
    required this.unreadCount,
    required this.imageUrl,
    required this.isOnline,
    required this.isGroup,
    this.isOfficial = false,
    this.isVerified = false,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  List<Color> _getAvatarGradient(String text) {
    final gradients = <List<Color>>[
      [const Color(0xFF1E4C7A), const Color(0xFF2563EB)],
      [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
      [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
      [const Color(0xFF0369A1), const Color(0xFF0284C7)],
      [const Color(0xFFB45309), const Color(0xFFF59E0B)],
    ];
    if (text.isEmpty) return gradients.first;
    return gradients[text.codeUnitAt(0) % gradients.length];
  }

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasUnread = unreadCount > 0;
    final avatarColors = _getAvatarGradient(name);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFEFF6FF)
            : (isOfficial
                ? const Color(0xFFF0FDF4)
                : (hasUnread ? const Color(0xFFF8FAFF) : Colors.white)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isOfficial
                  ? const Color(0xFF86EFAC)
                  : (hasUnread
                      ? const Color(0xFFBFDBFE)
                      : const Color(0xFFE2E8F0))),
          width: isSelected || hasUnread ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isOnline || hasUnread
                            ? LinearGradient(
                                colors: isOfficial
                                    ? [
                                        const Color(0xFF059669),
                                        const Color(0xFF10B981)
                                      ]
                                    : avatarColors,
                              )
                            : null,
                        border: !isOnline && !hasUnread
                            ? Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: isOfficial
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 50,
                                  height: 50,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0F766E),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified_user_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                            )
                          : CircleAvatar(
                              radius: 25,
                              backgroundColor: avatarColors.first,
                              backgroundImage: imageUrl.isNotEmpty
                                  ? NetworkImage(imageUrl)
                                  : null,
                              child: imageUrl.isEmpty
                                  ? Container(
                                      width: 50,
                                      height: 50,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: avatarColors,
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: isGroup
                                          ? const Icon(
                                              Icons.groups_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            )
                                          : Text(
                                              _getInitials(name),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                    )
                                  : null,
                            ),
                    ),
                    if (isOnline && !isGroup && !isSelected)
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 13.5,
                          height: 13.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.2),
                          ),
                        ),
                      ),
                    AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      scale: isSelected ? 1.0 : 0.0,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E4C7A).withOpacity(0.88),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.8,
                                fontWeight: hasUnread
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                color: isOfficial
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 5),
                            Image.asset(
                              'assets/images/Verified_Batch.png',
                              width: 16,
                              height: 16,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF0284C7),
                                size: 16,
                              ),
                            ),
                          ],
                          if (isOfficial) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'OFFICIAL',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (isTyping)
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'typing...',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          lastMessage.isEmpty
                              ? 'Tap to start conversation'
                              : lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.2,
                            color: isOfficial
                                ? const Color(0xFF047857)
                                : (hasUnread
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFF64748B)),
                            fontWeight: hasUnread || isOfficial
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (timeText.isNotEmpty)
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 11.2,
                          color: hasUnread
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF94A3B8),
                          fontWeight:
                              hasUnread ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (hasUnread && !isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7.5,
                          vertical: 2.5,
                        ),
                        constraints: const BoxConstraints(minWidth: 22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isOfficial
                                ? [
                                    const Color(0xFF059669),
                                    const Color(0xFF10B981)
                                  ]
                                : [
                                    const Color(0xFF1E4C7A),
                                    const Color(0xFF2563EB)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.28),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else if (isOnline && !hasUnread)
                      const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
