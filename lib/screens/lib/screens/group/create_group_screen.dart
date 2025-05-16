import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/group_model.dart';

class CreateGroupScreen extends StatefulWidget {
  final String teacherId;

  const CreateGroupScreen({super.key, required this.teacherId});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  List<String> selectedStudentIds = [];
  List<Map<String, dynamic>> allStudents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  Future<void> fetchStudents() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('type', isEqualTo: 'student')
        .get();

    setState(() {
      allStudents = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                'name': doc['name'] ?? 'Unnamed',
              })
          .toList();
      isLoading = false;
    });
  }

  void toggleSelection(String id) {
    setState(() {
      if (selectedStudentIds.contains(id)) {
        selectedStudentIds.remove(id);
      } else {
        selectedStudentIds.add(id);
      }
    });
  }

  Future<void> createGroup() async {
    final String groupId = const Uuid().v4();
    final String groupName = _groupNameController.text.trim();

    if (groupName.isEmpty || selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter group name and select students")),
      );
      return;
    }

    final newGroup = GroupModel(
      id: groupId,
      name: groupName,
      createdBy: widget.teacherId,
      imageUrl: '', // optional group image
      members: [widget.teacherId], // only teacher initially
      createdAt: Timestamp.now(),
    );

    // Step 1: Create group doc
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .set(newGroup.toMap());

    // Step 2: Send invites to selected students
    for (String studentId in selectedStudentIds) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .collection('group_invites')
          .doc(groupId)
          .set({
        'groupId': groupId,
        'groupName': groupName,
        'invitedBy': widget.teacherId,
        'status': 'pending',
        'sentAt': Timestamp.now(),
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Group created & invites sent!")),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Group")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select Students:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: allStudents.length,
                    itemBuilder: (context, index) {
                      final student = allStudents[index];
                      final isSelected =
                          selectedStudentIds.contains(student['id']);
                      return ListTile(
                        title: Text(student['name']),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.circle_outlined),
                        onTap: () => toggleSelection(student['id']),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.group_add),
                    label: const Text("Create Group"),
                    onPressed: createGroup,
                  ),
                ),
              ],
            ),
    );
  }
}