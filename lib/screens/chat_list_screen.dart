import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'group/group_chat_screen.dart';

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

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String _currentUserName = 'User';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserName();
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchText = _searchController.text.trim().toLowerCase();
        });
      }
    });
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
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          // ডার্ক ব্লু হেডার
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 30,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'FYBTT Chats',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSearchBar(),
              ],
            ),
          ),

          // চ্যাট লিস্ট
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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

                final chatDocs = snapshot.data!.docs;

                chatDocs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['lastMessageTime'] as Timestamp?;
                  final bTime = bData['lastMessageTime'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  physics: const BouncingScrollPhysics(),
                  itemCount: chatDocs.length,
                  itemBuilder: (context, index) {
                    final doc = chatDocs[index];
                    final chatData = doc.data() as Map<String, dynamic>;
                    final bool isGroup = chatData['isGroup'] == true;
                    final String lastMessage =
                        (chatData['lastMessage'] ?? '').toString();
                    final Timestamp? lastTime =
                        chatData['lastMessageTime'] as Timestamp?;
                    final int unreadCount = chatData['unreadCount'] ?? 0;

                    if (isGroup) {
                      final String groupName =
                          (chatData['groupName'] ?? 'Group Chat').toString();
                      final String groupImageUrl =
                          (chatData['groupImage'] ?? '').toString();

                      if (!_matchesSearch(chatData, groupName)) {
                        return const SizedBox.shrink();
                      }

                      return _ChatCard(
                        name: groupName,
                        lastMessage: lastMessage,
                        timeText: _formatTime(lastTime),
                        unreadCount: unreadCount,
                        imageUrl: groupImageUrl,
                        isOnline: false,
                        isGroup: true,
                        onTap: () => _openChat(
                          chatData: chatData,
                          chatDocId: doc.id,
                          receiverName: groupName,
                          receiverId: '',
                          receiverImage: groupImageUrl,
                        ),
                      );
                    } else {
                      final List<dynamic> participants =
                          chatData['participants'] ?? [];
                      final List<String> participantsList =
                          List<String>.from(participants);
                      participantsList.remove(widget.currentUserId);
                      if (participantsList.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final String receiverId = participantsList.first;

                      // Firestore-এ সরাসরি চ্যাট ডকুমেন্টে যদি Receiver Name সেভ থাকে তা ব্যাকআপ হিসেবে নেওয়া
                      String fallbackName = chatData['receiverName'] ??
                          chatData['teacherName'] ??
                          chatData['studentName'] ??
                          'User';

                      return StreamBuilder<dynamic>(
                        stream: _chatService.getUserStatusStream(
                          receiverId,
                          !widget.isTeacher,
                        ),
                        builder: (context, userSnapshot) {
                          String finalName = fallbackName;
                          String finalImageUrl = "";
                          bool isOnline = false;

                          if (userSnapshot.hasData && userSnapshot.data != null) {
                            final userData = userSnapshot.data;
                            Map<String, dynamic>? mapData;

                            if (userData is DocumentSnapshot && userData.exists) {
                              mapData = userData.data() as Map<String, dynamic>?;
                            } else if (userData is Map<String, dynamic>) {
                              mapData = userData;
                            }

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
                                      '')
                                  .toString();
                              isOnline = mapData['isOnline'] == true;
                            }
                          }

                          if (!_matchesSearch(chatData, finalName)) {
                            return const SizedBox.shrink();
                          }

                          return _ChatCard(
                            name: finalName,
                            lastMessage: lastMessage,
                            timeText: _formatTime(lastTime),
                            unreadCount: unreadCount,
                            imageUrl: finalImageUrl,
                            isOnline: isOnline,
                            isGroup: false,
                            onTap: () => _openChat(
                              chatData: chatData,
                              chatDocId: doc.id,
                              receiverName: finalName,
                              receiverId: receiverId,
                              receiverImage: finalImageUrl,
                            ),
                          );
                        },
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
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
          prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
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
  final String timeText;
  final int unreadCount;
  final String imageUrl;
  final bool isOnline;
  final bool isGroup;
  final VoidCallback onTap;

  const _ChatCard({
    required this.name,
    required this.lastMessage,
    required this.timeText,
    required this.unreadCount,
    required this.imageUrl,
    required this.isOnline,
    required this.isGroup,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Stack(
            children: [
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
              if (isOnline && !isGroup)
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
            ],
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3.0),
            child: Text(
              lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
              if (unreadCount > 0) ...[
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E4C7A),
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
