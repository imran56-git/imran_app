import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_utils.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? studentData;
  bool isLoading = true;
  bool isEditing = false;
  File? _selectedImage;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();

  String? gender;
  String? studentClass;
  List<String> selectedSubjects = [];

  @override
  void initState() {
    super.initState();
    fetchStudentData();
  }

  Future<void> fetchStudentData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await _firestore.collection('students').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          studentData = doc.data();
          _nameController.text = studentData?['name'] ?? '';
          _phoneController.text = studentData?['phone'] ?? '';
          _locationController.text = studentData?['location'] ?? '';
          _bioController.text = studentData?['bio'] ?? '';
          gender = studentData?['gender'];
          studentClass = studentData?['studentClass'];
          selectedSubjects = List<String>.from(studentData?['interestedSubjects'] ?? []);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Warning"),
        content: const Text("This action will permanently delete your account and all associated data. This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await _firestore.collection('students').doc(uid).delete();
        await _auth.currentUser?.delete();
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error deleting account")));
      }
    }
  }

  Future<void> _handleLogout() async {
    await _auth.signOut();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E4C7A),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') setState(() => isEditing = true);
              if (value == 'logout') _handleLogout();
              if (value == 'delete') _handleDeleteAccount();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text("Edit Profile")),
              const PopupMenuItem(value: 'logout', child: Text("Log Out")),
              const PopupMenuItem(value: 'delete', child: Text("Delete Account", style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 30),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E4C7A),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(radius: 50, backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : (studentData?['profileImageUrl'] != null ? NetworkImage(studentData!['profileImageUrl']) : null) as ImageProvider?),
                        const SizedBox(height: 10),
                        Text(_nameController.text, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: isEditing ? _buildEditForm() : _buildProfileView(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        _customEditField("Full Name", _nameController),
        _customEditField("Phone", _phoneController),
        _customEditField("Location", _locationController),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () => setState(() => isEditing = false), child: const Text("Save Changes")),
      ],
    );
  }

  Widget _buildProfileView() {
    return Column(
      children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [const Icon(Icons.location_on), Text(_locationController.text.isNotEmpty ? _locationController.text : "N/A")]))),
      ],
    );
  }

  Widget _customEditField(String label, TextEditingController controller) {
    return TextField(controller: controller, decoration: InputDecoration(labelText: label));
  }
}
