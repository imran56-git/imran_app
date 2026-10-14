import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  late TabController _tabController;

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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _isSelectionMode) {
        _clearSelection();
      }
      if (mounted) setState(() {});
    });
    _loadCurrentUserName();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchText = _searchController.text.trim().toLowerCase();
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
    }
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
    setState(() {
      if (_selectedChatDocIds.contains(docId)) {
        _selectedChatDocIds.remove(docId);
      } else {
        _selectedChatDocIds.add(docId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedChatDocIds.clear();
    });
  }

  void _confirmDeleteSelected() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Selected Chats?'),
        content: Text(
            'Are you sure you want to delete ${_selectedChatDocIds.length} selected chat(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
    return '${date.day}/${date.month}/${date.year}';
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

  Widget _buildStudentNetworkStyleTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF0F766E),
        indicatorWeight: 2.8,
        labelColor: const Color(0xFF0F766E),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          Tab(
            child: StreamBuilder<int>(
              stream: _chatService
                  .getTotalUnreadChatsCountStream(widget.currentUserId),
              builder: (context, snapshot) {
                final int count = snapshot.data ?? 0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Chats'),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
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
                final int count = snapshot.data ?? 0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Groups'),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
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
    );
  }

  Widget _buildPrivateChatsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getUserChatsStream(widget.currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1E4C7A)),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Failed to load chats.',
              style: TextStyle(fontSize: 14, color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final rawChatDocs = snapshot.data!.docs;
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
          padding: const EdgeInsets.symmetric(vertical: 10),
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
                name: officialName,
                lastMessage: lastMessage.isEmpty
                    ? 'Official Communication Desk'
                    : lastMessage,
                timeText: _formatTime(lastTime),
                unreadCount: unreadCount,
                imageUrl: '',
                isOnline: false,
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

            String fallbackName = chatData['receiverName'] ??
                chatData['teacherName'] ??
                chatData['studentName'] ??
                'User';

            return StreamBuilder<Map<String, dynamic>>(
              stream: _chatService.getUserStatusStream(
                receiverId,
                !widget.isTeacher,
              ),
              builder: (context, userSnapshot) {
                String finalName = fallbackName;
                String finalImageUrl = '';
                bool isOnline = false;

                if (userSnapshot.hasData && userSnapshot.data != null) {
                  final mapData = userSnapshot.data!;

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
                          '')
                      .toString();
                  isOnline = mapData['isOnline'] == true;
                }
                if (!_matchesSearch(chatData, finalName)) {
                  return const SizedBox.shrink();
                }

                return StreamBuilder<bool>(
                  stream:
                      _chatService.getTypingStatusStream(doc.id, receiverId),
                  builder: (context, typingSnap) {
                    final bool isTyping = typingSnap.data == true;
                    return _ChatCard(
                      name: finalName,
                      lastMessage: isTyping ? 'typing...' : lastMessage,
                      isTyping: isTyping,
                      timeText: _formatTime(lastTime),
                      unreadCount: unreadCount,
                      imageUrl: finalImageUrl,
                      isOnline: isOnline,
                      isGroup: false,
                      isOfficial: false,
                      isVerified: false,
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
        backgroundColor: const Color(0xFFF4F6F9),
        body: Column(
          children: [
            _buildTopHeader(),
            _buildStudentNetworkStyleTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPrivateChatsList(),
                  GroupListScreen(
                    currentUserId: widget.currentUserId,
                    currentUserName: _currentUserName,
                    isEmbedded: true,
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
    final double topPad = MediaQuery.of(context).padding.top;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey<bool>(_isSelectionMode),
        padding: EdgeInsets.only(
          top: topPad > 0 ? topPad + 10 : 16,
          bottom: 16,
          left: 16,
          right: 16,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1E4C7A),
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        child: _isSelectionMode
            ? Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _clearSelection,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedChatDocIds.length} Selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon:
                        const Icon(Icons.delete_outline, color: Colors.white),
                    onPressed: _confirmDeleteSelected,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) {
                      if (value == 'clear') _clearSelection();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            Icon(Icons.clear_all, color: Colors.black87),
                            SizedBox(width: 8),
                            Text('Deselect All'),
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
                      const Text(
                        'FYBTT Chats',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Row(
                        children: [
                          if (!widget.isTeacher)
                            IconButton(
                              visualDensity: VisualDensity.compact,
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
                          if (widget.isTeacher)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.group_add_rounded,
                                  color: Colors.white),
                              tooltip: 'Create New Group',
                              onPressed: () {
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
                  const SizedBox(height: 12),
                  _buildSearchBar(),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search chats...',
          hintStyle:
              TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          prefixIcon:
              const Icon(Icons.search, color: Colors.white70, size: 20),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white70, size: 18),
                  onPressed: _searchController.clear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF1E4C7A).withOpacity(0.08)
            : (isOfficial ? const Color(0xFFF0FDF4) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF1E4C7A)
              : (isOfficial ? const Color(0xFFBBF7D0) : Colors.transparent),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          onLongPress: onLongPress,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Stack(
            alignment: Alignment.center,
            children: [
              if (isOfficial)
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.teal.shade100,
                      child: const Icon(Icons.verified_rounded,
                          color: Colors.teal, size: 28),
                    ),
                  ),
                )
              else
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF1E4C7A).withOpacity(0.1),
                  backgroundImage:
                      imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                  child: imageUrl.isEmpty
                      ? Icon(
                          isGroup ? Icons.groups : Icons.person,
                          size: 26,
                          color: const Color(0xFF1E4C7A),
                        )
                      : null,
                ),
              if (isOnline && !isGroup && !isOfficial && !isSelected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: isSelected ? 1.0 : 0.0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isSelected ? 1.0 : 0.0,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E4C7A).withOpacity(0.85),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.check, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ],
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isOfficial
                        ? const Color(0xFF0F766E)
                        : Colors.black87,
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
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3.0),
            child: Text(
              lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isTyping
                    ? const Color(0xFF22C55E)
                    : (isOfficial
                        ? const Color(0xFF0D9488)
                        : Colors.grey.shade600),
                fontWeight: (isTyping || isOfficial)
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 11,
                  color: unreadCount > 0
                      ? const Color(0xFF1E4C7A)
                      : Colors.grey.shade500,
                  fontWeight: unreadCount > 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              if (unreadCount > 0 && !isSelected) ...[
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOfficial
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF1E4C7A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
