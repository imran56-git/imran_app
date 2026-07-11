import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'group/group_chat_screen.dart';
import '../../utils/chat_colors.dart';

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
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

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
    required String receiverImage,
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
            chatId: chatId,
            currentUserId: widget.currentUserId,
            receiverId: receiverId,
            receiverName: receiverName, // ChatScreen এর কন্সট্রাক্টরের সাথে ম্যাচ করা হলো
            receiverImage: receiverImage,
          ),
        ),
      );
    }
  }

  bool _matchesSearch(Map<String, dynamic> chatData, String otherUserName) {
    if (_searchText.isEmpty) return true;
    final name = otherUserName.toLowerCase();
    final lastMessage = (chatData['lastMessage'] ?? '').toString().toLowerCase();
    return name.contains(_searchText) || lastMessage.contains(_searchText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: ChatColors.appBarLight,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'WhatsApp',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
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
                  return const Center(child: CircularProgressIndicator(color: ChatColors.primaryApp));
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Something went wrong.',
                      style: TextStyle(fontSize: 14, color: Colors.red),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final chatDocs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: chatDocs.length,
                  itemBuilder: (context, index) {
                    final doc = chatDocs[index];
                    final chatData = doc.data() as Map<String, dynamic>;
                    final bool isGroup = chatData['isGroup'] == true;
                    final String lastMessage = (chatData['lastMessage'] ?? '').toString();
                    final Timestamp? lastTime = chatData['lastMessageTime'] as Timestamp?;
                    final int unreadCount = chatData['unreadCount'] ?? 0;

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
                          receiverImage: groupImageUrl,
                        ),
                      );
                    } else {
                      final List<dynamic> participants = chatData['participants'] ?? [];
                      final List<String> participantsList = List<String>.from(participants);
                      participantsList.remove(widget.currentUserId);
                      if (participantsList.isEmpty) return const SizedBox.shrink();
                      final String receiverId = participantsList.first;

                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(receiverId)
                            .snapshots(),
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
                          final String userStatus = userData['status'] ?? 'Offline';
                          final bool isOnline = userStatus == 'Online';

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
                              receiverImage: receiverImageUrl,
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
        backgroundColor: ChatColors.primaryApp,
        onPressed: () {},
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
            prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
            suffixIcon: _searchText.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                    onPressed: _searchController.clear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No chats yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
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
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty
                ? Icon(isGroup ? Icons.groups : Icons.person, size: 28, color: Colors.grey)
                : null,
          ),
          if (isOnline && !isGroup)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 13,
                height: 13,
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
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3.0),
        child: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeText,
            style: TextStyle(fontSize: 12, color: unreadCount > 0 ? ChatColors.primaryApp : Colors.grey),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: ChatColors.primaryApp,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
