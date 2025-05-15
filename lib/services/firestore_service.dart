import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? teacherData;
  bool isLoading = true;
  bool isEditing = false;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTeacherData();
  }

  Future<void> fetchTeacherData() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final doc = await _firestore.collection('teachers').doc(uid).get();
      if (doc.exists) {
        setState(() {
          teacherData = doc.data();
          _nameController.text = teacherData?['name'] ?? '';
          _phoneController.text = teacherData?['phone'] ?? '';
          _locationController.text = teacherData?['currentLocation'] ?? '';
          _subjectController.text = teacherData?['subject'] ?? '';
          _experienceController.text = teacherData?['experience'] ?? '';
          _bioController.text = teacherData?['bio'] ?? '';
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching teacher data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> updateTeacherProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('teachers').doc(uid).update({
        'name': _nameController.text,
        'locations': teacherLocations
    .map((loc) => {
          'latitude': loc.latitude,
          'longitude': loc.longitude,
        })
    .toList(),
        'phone': _phoneController.text,
        'currentLocation': _locationController.text,
        'subject': _subjectController.text,
        'experience': _experienceController.text,
        'bio': _bioController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );

      setState(() {
        isEditing = false;
        teacherData?['name'] = _nameController.text;
        teacherData?['phone'] = _phoneController.text;
        teacherData?['currentLocation'] = _locationController.text;
        teacherData?['subject'] = _subjectController.text;
        teacherData?['experience'] = _experienceController.text;
        teacherData?['bio'] = _bioController.text;
      });
    } catch (e) {
      print('Error updating teacher profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Profile'),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                isEditing = !isEditing;
              });
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : teacherData == null
              ? const Center(child: Text('No profile data found.'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: teacherData!['profileImageUrl'] != null
                            ? NetworkImage(teacherData!['profileImageUrl'])
                            : const AssetImage('assets/images/teacher_avatar.png') as ImageProvider,
                      ),
                      const SizedBox(height: 16),

                      buildEditableField(label: 'Name', controller: _nameController),
                      buildEditableField(label: 'Phone', controller: _phoneController),
                      buildEditableField(label: 'Location', controller: _locationController),
                      buildEditableField(label: 'Subject', controller: _subjectController),
                      buildEditableField(label: 'Experience', controller: _experienceController),
                      buildEditableField(label: 'Bio', controller: _bioController, maxLines: 3),

                      const SizedBox(height: 16),
                      Text('Email: ${teacherData!['email'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Gender: ${teacherData!['gender'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),

                      const SizedBox(height: 24),
                      isEditing
                          ? ElevatedButton(
                              onPressed: updateTeacherProfile,
                              child: const Text('Save Changes'),
                            )
                          : ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Contact feature coming soon!')),
                                );
                              },
                              child: const Text('Contact Now'),
                            ),
                    ],
                  ),
                ),
    );
  }

  Widget buildEditableField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        isEditing
            ? TextField(
                controller: controller,
                maxLines: maxLines,
                decoration: InputDecoration(
                  hintText: 'Enter $label',
                  border: const OutlineInputBorder(),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(controller.text, style: const TextStyle(fontSize: 16)),
              ),
        const SizedBox(height: 12),
      ],
    );
  }
}