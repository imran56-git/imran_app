import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/group_model.dart';
import 'create_group_screen.dart';

class GroupListScreen extends StatefulWidget {
  @override
  _GroupListScreenState createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _navigateToCreateGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateGroupScreen()),
    );
  }

  Widget _buildGroupItem(GroupModel group) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: ListTile(
        title: Text(group.name),
        subtitle: Text(group.description),
        trailing: Text('${group.members.length} members'),
        onTap: () {
          // TODO: Implement group details or chat
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Groups'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _navigateToCreateGroup,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('groups').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No groups found.'));
          }

          final groups = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return GroupModel.fromMap(data);
          }).toList();

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) => _buildGroupItem(groups[index]),
          );
        },
      ),
    );
  }
}
