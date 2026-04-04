import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

// Ensure your GroupModel path is correct
// import '../../models/group_model.dart'; 

class CreateGroupScreen extends StatefulWidget {
  final String teacherId;
  const CreateGroupScreen({super.key, required this.teacherId});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  List<Map<String, dynamic>> selectedStudents = []; // Stores full student map
  List<Map<String, dynamic>> allStudents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  Future<void> fetchStudents() async {
    try {
      // Fetching only students. Make sure your Firestore field name is 'type' or 'role'
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: 'student') 
          .get();

      setState(() {
        allStudents = snapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc['name'] ?? 'Unnamed Student',
          'photoUrl': doc['photoUrl'] ?? '',
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      _showSnackBar("Error loading students: $e");
    }
  }

  void _toggleSelection(Map<String, dynamic> student) {
    setState(() {
      final index = selectedStudents.indexWhere((s) => s['id'] == student['id']);
      if (index != -1) {
        selectedStudents.removeAt(index);
      } else {
        selectedStudents.add(student);
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> createGroup() async {
    String groupName = _groupNameController.text.trim();
    
    if (groupName.isEmpty) {
      _showSnackBar("Please enter a group name");
      return;
    }
    if (selectedStudents.isEmpty) {
      _showSnackBar("Please select at least one student");
      return;
    }

    setState(() => isLoading = true);
    final String groupId = const Uuid().v4();

    try {
      // 1. Create Group Document
      await FirebaseFirestore.instance.collection('groups').doc(groupId).set({
        'id': groupId,
        'name': groupName,
        'createdBy': widget.teacherId,
        'members': [widget.teacherId], // Initial member is only the teacher
        'admins': [widget.teacherId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': 'Group Created',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'groupImageUrl': '', 
      });

      // 2. Batch Invite Operations
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var student in selectedStudents) {
        var inviteRef = FirebaseFirestore.instance
            .collection('users')
            .doc(student['id'])
            .collection('group_invites')
            .doc(groupId);
        
        batch.set(inviteRef, {
          'groupId': groupId,
          'groupName': groupName,
          'invitedBy': widget.teacherId,
          'status': 'pending',
          'sentAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Group created and invitations sent successfully!");

    } catch (e) {
      _showSnackBar("Failed to create group: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Group", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading && allStudents.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF128C7E)))
          : Column(
              children: [
                // Group Name Section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  color: Colors.white,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey[200],
                        child: Icon(Icons.camera_alt, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextField(
                          controller: _groupNameController,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                            hintText: 'Enter group subject...',
                            border: UnderlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Selected Students Horizontal Preview
                if (selectedStudents.isNotEmpty)
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: selectedStudents.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                child: Text(selectedStudents[index]['name'][0]),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: InkWell(
                                  onTap: () => _toggleSelection(selectedStudents[index]),
                                  child: const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.grey,
                                    child: Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                const Divider(height: 1),
                
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Select Members",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ),

                // Student List
                Expanded(
                  child: ListView.builder(
                    itemCount: allStudents.length,
                    itemBuilder: (context, index) {
                      final student = allStudents[index];
                      final isSelected = selectedStudents.any((s) => s['id'] == student['id']);
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? const Color(0xFF128C7E) : Colors.grey[300],
                          child: Text(
                            student['name'][0],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(student['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: isSelected 
                            ? const Icon(Icons.check_circle, color: Color(0xFF128C7E))
                            : const Icon(Icons.circle_outlined, color: Colors.grey),
                        onTap: () => _toggleSelection(student),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF128C7E),
        onPressed: isLoading ? null : createGroup,
        child: isLoading 
            ? const CircularProgressIndicator(color: Colors.white) 
            : const Icon(Icons.check, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }
}
