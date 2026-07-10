import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'group/group_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String currentUserId;

  const ChatListScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  String _currentUserName = 'User';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserName();

    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });
  }

  Future<void> _loadCurrentUserName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();

      final data = doc.data();
      if (data == null || !mounted) return;

      setState(() {
        _currentUserName = (data['name'] ??
                data['fullName'] ??
                data['studentName'] ??
                data['username'] ??
                'User')
            .toString();
      });
    } catch (_) {}
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
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    if (isToday) {
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
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
  }) {
    final bool isGroup = chatData['isGroup'] == true;

    final String chatId = chatData['chatId']?.toString().isNotEmpty == true
        ? chatData['chatId'].toString()
        : chatDocId;

    if (isGroup) {
      final String groupName = (chatData['groupName'] ?? 'Group Chat').toString();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            groupId: chatId,
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
            teacherName: receiverName,
            chatId: chatId,
            currentUserId: widget.currentUserId,
            receiverId: receiverId,
          ),
        ),
      );
    }
  }

  bool _matchesSearch(Map<String, dynamic> chatData, String otherUserName) {
    if (_searchText.isEmpty) return true;

    final name = otherUserName.toLowerCase();

    final lastMessage = (chatData['lastMessage'] ?? '')
        .toString()
        .toLowerCase();

    return name.contains(_searchText) || lastMessage.contains(_searchText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.chat_bubble_rounded, 
                  color: Color(0xFF112B44), 
                  size: 32
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'FYBTT',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: widget.currentUserId)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Something went wrong.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: Colors.red),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final chatDocs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: chatDocs.length,
                  itemBuilder: (context, index) {
                    final doc = chatDocs[index];
                    final chatData = doc.data() as Map<String, dynamic>;
                    final bool isGroup = chatData['isGroup'] == true;

                    final String lastMessage =
                        (chatData['lastMessage'] ?? 'No messages yet').toString();

                    final Timestamp? lastTime =
                        chatData['lastMessageTime'] as Timestamp?;

                    final int unreadCount =
                        (chatData['unreadCount'] ?? 0) is int
                            ? chatData['unreadCount'] as int
                            : int.tryParse('${chatData['unreadCount']}') ?? 0;

                    if (isGroup) {
                      final String groupName = (chatData['groupName'] ?? 'Group Chat').toString();
                      final String groupImageUrl = (chatData['groupImage'] ?? '').toString();

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
                        ),
                      );
                    } else {
                      final List<dynamic> participants = chatData['participants'] ?? [];
                      participants.remove(widget.currentUserId);
                      if (participants.isEmpty) return const SizedBox.shrink();

                      final String receiverId = participants.first.toString();

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(receiverId)
                            .get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                            return const SizedBox.shrink();
                          }

                          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                          final String receiverName = (userData['name'] ??
                                  userData['fullName'] ??
                                  userData['studentName'] ??
                                  'User')
                              .toString();
                          final String receiverImageUrl = (userData['profileImageUrl'] ?? userData['photoUrl'] ?? '').toString();
                          final bool isOnline = userData['isOnline'] == true;

                          if (!_matchesSearch(chatData, receiverName)) {
                            return const SizedBox.shrink();
                          }

                          return _ChatCard(
                            name: receiverName,
                            lastMessage: lastMessage,
                            timeText: _formatTime(lastTime),
                            unreadCount: unreadCount,
                            imageUrl: receiverImageUrl,
                            isOnline: isOnline,
                            isGroup: false,
                            onTap: () => _openChat(
                              chatData: chatData, 
                              chatDocId: doc.id,
                              receiverName: receiverName,
                              receiverId: receiverId,
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF112B44),
        onPressed: () {
          //Snack Bar logic updated if required
        },
        child: const Icon(Icons.message_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFF112B44),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search chats...',
            hintStyle: TextStyle(color: Colors.grey.shade500),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchText.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: _searchController.clear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      children: [
        Icon(
          Icons.chat_bubble_outline,
          size: 72,
          color: Colors.blueGrey.shade300,
        ),
        const SizedBox(height: 20),
        const Text(
          'No chats yet',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          'Your conversations will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNoSearchResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No chats found for "$_searchText"',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
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
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B1B1B),
                              ),
                            ),
                          ),
                          if (timeText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                timeText,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 10),
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              // অনলাইন থাকলে সবুজ বর্ডার, অফলাইন থাকলে সাধারণ বর্ডার
              color: isOnline ? const Color(0xFF22C55E) : Colors.grey.shade300,
              width: 2.4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              child: imageUrl.isEmpty
                  ? Icon(
                      isGroup ? Icons.groups_rounded : Icons.person,
                      size: 30,
                      color: Colors.grey.shade700,
                    )
                  : null,
            ),
          ),
        ),
        if (isOnline && !isGroup)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
