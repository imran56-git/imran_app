import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import '../../models/group_model.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

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

  // Formats timestamp into a readable string (Today's time or Previous date)
  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();
    
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return DateFormat.jm().format(date); // Output: 10:30 AM
    }
    return DateFormat('dd/MM/yy').format(date); // Output: 04/04/26
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Groups', 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar Implementation
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search your groups...",
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Fetching only groups where the current user is a member
              stream: _firestore
                  .collection('groups')
                  .where('members', arrayContains: widget.currentUserId)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF128C7E)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyPlaceholder();
                }

                // Filtering list based on search query
                var groupDocs = snapshot.data!.docs.where((doc) {
                  return doc['name'].toString().toLowerCase().contains(_searchQuery);
                }).toList();

                return ListView.separated(
                  itemCount: groupDocs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 75, color: Color(0xFFEEEEEE)),
                  itemBuilder: (context, index) {
                    var data = groupDocs[index].data() as Map<String, dynamic>;
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: (data['groupImageUrl'] != null && data['groupImageUrl'] != "") 
                            ? NetworkImage(data['groupImageUrl']) 
                            : null,
                        child: (data['groupImageUrl'] == null || data['groupImageUrl'] == "") 
                            ? const Icon(Icons.groups, color: Colors.grey, size: 30) 
                            : null,
                      ),
                      title: Text(
                        data['name'] ?? 'Unknown Group',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        data['lastMessage'] ?? "Start a conversation...",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.blueGrey, fontSize: 14),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatDateTime(data['lastMessageTime'] as Timestamp?),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          // Optional: Unread message badge can be placed here
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupChatScreen(
                              groupId: data['id'],
                              groupName: data['name'],
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
        backgroundColor: const Color(0xFF128C7E),
        elevation: 4,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateGroupScreen(teacherId: widget.currentUserId)),
          );
        },
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  // Placeholder for when no groups are found
  Widget _buildEmptyPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 100, color: Colors.grey[200]),
          const SizedBox(height: 15),
          const Text(
            "No active groups found", 
            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)
          ),
        ],
      ),
    );
  }
}
