import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'create_group_screen.dart';
import 'group_chat_screen.dart';
import '../../utils/chat_colors.dart';

class GroupListScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const GroupListScreen({
    super.key, 
    required this.currentUserId, 
    required this.currentUserName
  });

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = "";

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return DateFormat.jm().format(date);
    }
    return DateFormat('dd/MM/yy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Groups', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: ChatColors.appBarLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Search your groups...",
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('groups')
                  .where('members', arrayContains: widget.currentUserId)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: ChatColors.primaryApp));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyPlaceholder();
                }

                var groupDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final groupName = (data['groupName'] ?? data['name'] ?? '').toString().toLowerCase();
                  return groupName.contains(_searchQuery);
                }).toList();

                return ListView.separated(
                  itemCount: groupDocs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 75, color: Color(0xFFEEEEEE)),
                  itemBuilder: (context, index) {
                    var doc = groupDocs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    
                    final String id = data['groupId'] ?? data['id'] ?? doc.id;
                    final String groupName = data['groupName'] ?? data['name'] ?? 'Unknown Group';
                    final String groupImageUrl = data['groupImage'] ?? data['groupImageUrl'] ?? '';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: groupImageUrl.isNotEmpty ? NetworkImage(groupImageUrl) : null,
                        child: groupImageUrl.isEmpty ? const Icon(Icons.groups, color: Colors.grey, size: 28) : null,
                      ),
                      title: Text(
                        groupName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3.0),
                        child: Text(
                          data['lastMessage'] ?? "Start a conversation...",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                      trailing: Text(
                        _formatDateTime(data['lastMessageTime'] as Timestamp?),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupChatScreen(
                              groupId: id,
                              groupName: groupName,
                              currentUserId: widget.currentUserId,
                              currentUserName: widget.currentUserName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ChatColors.primaryApp,
        elevation: 4,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateGroupScreen(teacherId: widget.currentUserId)),
          );
        },
        child: const Icon(Icons.group_add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            "No active groups found", 
            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }
}
