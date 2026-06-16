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

  // Full updated subject list
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated Successfully!')));
        setState(() => isEditing = false);
        fetchStudentData();
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = studentData?['profileImageUrl'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Student Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              if(isEditing) fetchStudentData(); // Reset data if cancel
              setState(() => isEditing = !isEditing);
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildProfileHeader(imageUrl),
                  const SizedBox(height: 25),
                  isEditing ? _buildEditForm() : _buildProfileView(),
                  if (!isEditing) _buildActionButtons(),
                  if (!isEditing) _buildRecentChatsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(String? imageUrl) {
    return Center(
      child: GestureDetector(
        onTap: isEditing ? pickImage : null,
        child: CircleAvatar(
          radius: 65,
          backgroundColor: Colors.blue[50],
          backgroundImage: _selectedImage != null
              ? FileImage(_selectedImage!)
              : (imageUrl != null ? NetworkImage(imageUrl) : null) as ImageProvider?,
          child: (imageUrl == null && _selectedImage == null)
              ? Icon(Icons.person, size: 65, color: Colors.blue[800])
              : isEditing ? const Icon(Icons.camera_alt, color: Colors.white70) : null,
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        _customEditField("Full Name", _nameController, Icons.person),
        _customEditField("Phone Number", _phoneController, Icons.phone),
        _customEditField("Home Area", _locationController, Icons.location_on),
        _customEditField("Bio", _bioController, Icons.info, maxLines: 3),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: gender,
          decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder(), prefixIcon: Icon(Icons.wc)),
          onChanged: (val) => setState(() => gender = val),
          items: const [
            DropdownMenuItem(value: "Male", child: Text("Male")),
            DropdownMenuItem(value: "Female", child: Text("Female")),
          ],
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(
          value: studentClass,
          decoration: const InputDecoration(labelText: "Class/Level", border: OutlineInputBorder(), prefixIcon: Icon(Icons.school)),
          onChanged: (val) => setState(() => studentClass = val),
          items: classOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        ),
        const SizedBox(height: 20),
        _buildSubjectPicker(),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800], 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: updateStudentProfile,
            child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoTile("Name", _nameController.text, Icons.person_outline),
        _infoTile("Phone", _phoneController.text, Icons.phone_android),
        _infoTile("Location", _locationController.text, Icons.map_outlined),
        _infoTile("Bio", _bioController.text, Icons.info_outline),
        _infoTile("Gender", gender ?? "N/A", Icons.wc),
        _infoTile("Class", studentClass ?? "N/A", Icons.school_outlined),
        const Divider(height: 30),
        const Text("Interested Subjects", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: selectedSubjects.map((s) => Chip(
            label: Text(s, style: const TextStyle(fontSize: 12)), 
            backgroundColor: Colors.blue[50],
            side: BorderSide.none,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildSubjectPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Interested Subjects", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _subjectSearchController,
          decoration: const InputDecoration(hintText: "Search Subject...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Container(
          height: 200,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: allSubjects
                .where((s) => s.toLowerCase().contains(_subjectSearchController.text.toLowerCase()))
                .map((s) => CheckboxListTile(
                      title: Text(s),
                      value: selectedSubjects.contains(s),
                      activeColor: Colors.blue[800],
                      onChanged: (val) {
                        setState(() { val! ? selectedSubjects.add(s) : selectedSubjects.remove(s); });
                      },
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 25),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text("UPLOAD PAYMENT CONFIRMATION"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple, 
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          ),
          onPressed: () {
            // Navigation logic for payment
          },
        ),
      ),
    );
  }

  Widget _buildRecentChatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Divider(),
        const Text("Recent Conversations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('chats')
              .where('participants', arrayContains: _auth.currentUser!.uid)
              .orderBy('lastMessageTime', descending: true) // Ensuring latest chat is on top
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("No recent messages.", style: TextStyle(color: Colors.grey)),
            );
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final chat = snapshot.data!.docs[index];
                final participants = List<String>.from(chat['participants']);
                final tId = participants.firstWhere((id) => id != _auth.currentUser!.uid);
                return _buildChatTile(tId, chat);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildChatTile(String teacherId, QueryDocumentSnapshot chat) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('teachers').doc(teacherId).get(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox();
        final teacher = snap.data!.data() as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(backgroundImage: teacher['profileImageUrl'] != null ? NetworkImage(teacher['profileImageUrl']) : null),
            title: Text(teacher['name'] ?? 'Teacher', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(chat['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right, color: Colors.blue),
            onTap: () {
              // Navigation to Chat Screen
            },
          ),
        );
      },
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.blue[800]),
      ),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value.isEmpty ? "Not set" : value, style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500)),
    );
  }

  Widget _customEditField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label, 
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))
        ),
      ),
    );
  }
}
