import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'group/group_chat_screen.dart';
import '../../utils/chat_colors.dart';

class ChatListScreen extends StatefulWidget {
  final String currentUserId;
  final bool isTeacher; // টিচার নাকি স্টুডেন্ট তা ডিটেক্ট করার জন্য কোর প্যারামিটার

  const ChatListScreen({
    super.key,
    required this.currentUserId,
    required this.isTeacher,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
      // কালেকশন আর্কিটেকচার অনুযায়ী সেফ ডেটা রিড
      final targetCollection = widget.isTeacher ? 'teachers' : 'students';
      final doc = await _firestore.collection(targetCollection).doc(widget.currentUserId).get();
      if (!doc.exists || !mounted) return;
      final data = doc.data();
      if (data == null) return;
      setState(() {
        _currentUserName = (data['name'] ?? data['displayName'] ?? 'User').toString();
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

    if (isGroup) {
      final String groupName = (chatData['groupName'] ?? 'Group Chat').toString();
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
      // পূর্ববর্তী ধাপে রিফ্যাক্টর করা সেফ কনস্ট্রাক্টর ও রুট সিঙ্ক (ব্ল্যাক স্ক্রিন ফিক্সড)
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
    final lastMessage = (chatData['lastMessage'] ?? '').toString().toLowerCase();
    return name.contains(_searchText) || lastMessage.contains(_searchText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF006653), // প্রিমিয়াম হোয়াটসঅ্যাপ গ্রিন থিম
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'FYBTT Chats',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .where('participants', arrayContains: widget.currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF006653)));
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Failed to load chats.', style: TextStyle(fontSize: 14, color: Colors.red)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final chatDocs = snapshot.data!.docs;
                
                // মেমোরি সর্টিং ইঞ্জিন (নো ইনডেক্স ক্র্যাশ)
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
                  physics: const BouncingScrollPhysics(),
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

                      if (!_matchesSearch(chatData, groupName)) return const SizedBox.shrink();

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

                      // রোল বেসড ডেডিকেটেড কালেকশন ম্যাপিং (টিচার/স্টুডেন্ট আইডি সেফটি ফলব্যাক)
                      final targetOppositeCollection = widget.isTeacher ? 'students' : 'teachers';

                      return StreamBuilder<DocumentSnapshot>(
                        stream: _firestore.collection(targetOppositeCollection).doc(receiverId).snapshots(),
                        builder: (context, userSnapshot) {
                          String finalName = "User";
                          String finalImageUrl = "";
                          bool isOnline = false;

                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                            if (userData != null) {
                              finalName = (userData['name'] ?? userData['displayName'] ?? 'User').toString();
                              finalImageUrl = (userData['profileImageUrl'] ?? userData['profilePic'] ?? '').toString();
                              isOnline = userData['isOnline'] == true;
                            }
                          }

                          if (!_matchesSearch(chatData, finalName)) return const SizedBox.shrink();

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
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Container(
        height: 45,
        decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(24)),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search chats...',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
            suffixIcon: _searchText.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 18), onPressed: _searchController.clear)
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
          const Text('No chats yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
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
            backgroundColor: Colors.grey.shade100,
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty ? Icon(isGroup ? Icons.groups : Icons.person, size: 26, color: Colors.grey) : null,
          ),
          if (isOnline && !isGroup)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              ),
            ),
        ],
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3.0),
        child: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(timeText, style: TextStyle(fontSize: 11, color: unreadCount > 0 ? const Color(0xFF006653) : Colors.grey)),
          if (unreadCount > 0) ...[
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF006653), borderRadius: BorderRadius.circular(10)),
              child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}
