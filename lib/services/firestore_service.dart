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

  // Controllers for text fields
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

  // --- Fetch Teacher Data from Firestore ---
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
      debugPrint('Fetch Error: $e');
      setState(() => isLoading = false);
    }
  }

  // --- Update Profile Logic ---
  Future<void> updateTeacherProfile() async {
    if (_nameController.text.isEmpty) {
      _showSnackBar("Name cannot be empty");
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // Logic to preserve existing location coordinates if any
      List locations = teacherData?['locations'] ?? [];

      await _firestore.collection('teachers').doc(uid).update({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'currentLocation': _locationController.text,
        'subject': _subjectController.text,
        'experience': _experienceController.text,
        'bio': _bioController.text,
        'locations': locations, // Preserving current coordinates list
      });

      _showSnackBar('Profile updated successfully');

      setState(() {
        isEditing = false;
        teacherData?['name'] = _nameController.text;
      });
    } catch (e) {
      debugPrint('Update Error: $e');
      _showSnackBar("Update failed. Please try again.");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.cancel_outlined : Icons.edit_note, size: 28),
            onPressed: () => setState(() => isEditing = !isEditing),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF128C7E)))
          : teacherData == null
              ? const Center(child: Text('Profile not found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // --- Profile Image Header ---
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: teacherData!['profileImageUrl'] != null
                                  ? NetworkImage(teacherData!['profileImageUrl'])
                                  : null,
                              child: teacherData!['profileImageUrl'] == null
                                  ? const Icon(Icons.person, size: 60, color: Colors.grey)
                                  : null,
                            ),
                            if (isEditing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF128C7E),
                                  child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // --- Dynamic Profile Form ---
                      _buildField("Full Name", _nameController, Icons.person_outline),
                      _buildField("Contact Number", _phoneController, Icons.phone_android),
                      _buildField("Teaching Subject", _subjectController, Icons.book_outlined),
                      _buildField("Location", _locationController, Icons.location_on_outline),
                      _buildField("Experience", _experienceController, Icons.history_edu),
                      _buildField("Professional Bio", _bioController, Icons.description_outlined, maxLines: 4),

                      const SizedBox(height: 20),
                      
                      // --- Read-only Information ---
                      _buildInfoRow("Email", teacherData!['email'] ?? 'N/A'),
                      _buildInfoRow("Account Status", "Verified Teacher"),

                      const SizedBox(height: 30),

                      if (isEditing)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF128C7E),
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: updateTeacherProfile,
                          child: const Text('Save Profile Settings', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                    ],
                  ),
                ),
    );
  }

  // Helper widget for editable fields
  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          isEditing
              ? TextField(
                  controller: controller,
                  maxLines: maxLines,
                  decoration: InputDecoration(
                    prefixIcon: Icon(icon, size: 20),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                  ),
                )
              : Row(
                  children: [
                    Icon(icon, size: 20, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(child: Text(controller.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
