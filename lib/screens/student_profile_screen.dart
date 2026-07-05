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
  final _subjectSearchController = TextEditingController();

  String? gender;
  String? studentClass;
  List<String> selectedSubjects = [];

  final List<String> allSubjects = [
    'Mathematics', 'Physics', 'Chemistry', 'Biology', 'Computer Science',
    'English', 'Bengali', 'Hindi', 'Sanskrit', 'History', 'Geography',
    'Civics', 'Political Science', 'Economics', 'Philosophy', 'Psychology',
    'Sociology', 'Environmental Studies', 'General Science', 'Life Science',
    'Physical Science', 'Social Studies', 'Web Development', 'App Development',
    'Cyber Security', 'Data Science', 'Artificial Intelligence', 'Robotics',
    'Public Speaking', 'Statistics', 'Legal Studies', 'Fine Arts', 'Music'
  ];

  final List<String> classOptions = [
    'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5',
    'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10',
    'Class 11', 'Class 12', 'College', 'University', 'Others',
  ];

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

  Future<void> updateStudentProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => isLoading = true);

    try {
      String? imageUrl = studentData?['profileImageUrl'];

      if (_selectedImage != null) {
        File? compressedFile = await ImageHelper.compressImage(_selectedImage!);
        final ref = _storage.ref().child('students/$uid/profile.jpg');
        await ref.putFile(compressedFile ?? _selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      await _firestore.collection('students').doc(uid).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'bio': _bioController.text.trim(),
        'gender': gender,
        'studentClass': studentClass,
        'interestedSubjects': selectedSubjects,
        'profileImageUrl': imageUrl,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated!')));
        setState(() => isEditing = false);
        fetchStudentData();
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E4C7A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => isEditing = !isEditing),
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
                        Text(studentClass ?? "", style: const TextStyle(color: Colors.white70, fontSize: 16)),
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
        DropdownButtonFormField<String>(
          value: gender,
          decoration: const InputDecoration(labelText: "Gender"),
          onChanged: (val) => setState(() => gender = val),
          items: ["Male", "Female"].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
        ),
        DropdownButtonFormField<String>(
          value: studentClass,
          decoration: const InputDecoration(labelText: "Class"),
          onChanged: (val) => setState(() => studentClass = val),
          items: classOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        ),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: updateStudentProfile, child: const Text("Save Changes")),
      ],
    );
  }

  Widget _buildProfileView() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [const Icon(Icons.school), Text(studentClass ?? "N/A")]),
                Column(children: [const Icon(Icons.location_on), Text(_locationController.text.isNotEmpty ? _locationController.text : "N/A")]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Align(alignment: Alignment.centerLeft, child: Text("Interested Subjects", style: TextStyle(fontWeight: FontWeight.bold))),
        Wrap(spacing: 8, children: selectedSubjects.map((s) => Chip(label: Text(s))).toList()),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {}, child: const Text("UPLOAD PAYMENT CONFIRMATION"))),
      ],
    );
  }

  Widget _customEditField(String label, TextEditingController controller) {
    return TextField(controller: controller, decoration: InputDecoration(labelText: label));
  }
}
