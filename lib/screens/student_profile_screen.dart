import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final _institutionController = TextEditingController();
  final _schoolController = TextEditingController();
  final _collegeController = TextEditingController();

  String? gender;
  String? studentClass;
  List<String> selectedSubjects = [];

  final List<String> classOptions = [
    'Class 1',
    'Class 2',
    'Class 3',
    'Class 4',
    'Class 5',
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10',
    'Class 11',
    'Class 12',
    'College',
    'University',
    'Others',
  ];

  final List<String> subjectOptions = const [
    "Mathematics",
    "Physics",
    "Chemistry",
    "Biology",
    "English",
    "Computer Science",
    "History",
    "Geography",
  ];

  @override
  void initState() {
    super.initState();
    fetchStudentData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _institutionController.dispose();
    _schoolController.dispose();
    _collegeController.dispose();
    super.dispose();
  }

  Future<void> fetchStudentData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      return;
    }

    try {
      final doc = await _firestore.collection('students').doc(uid).get();

      if (!mounted) return;

      final data = doc.data() ?? {};

      setState(() {
        studentData = data;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _locationController.text = data['location'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _institutionController.text = data['institution'] ?? '';
        _schoolController.text = data['schoolName'] ?? '';
        _collegeController.text = data['collegeName'] ?? '';
        gender = data['gender'];
        studentClass = data['studentClass'];
        selectedSubjects =
            List<String>.from(data['interestedSubjects'] ?? []);
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (!mounted) return;
    setState(() {
      _selectedImage = File(picked.path);
    });
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "This will permanently delete your account and all your data.\n\nAre you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final uid = user.uid;

      await _firestore.collection("students").doc(uid).delete();

      await _firestore
          .collection("usernames")
          .doc(uid)
          .delete()
          .catchError((_) {});

      await _storage
          .ref("students/$uid/profile.jpg")
          .delete()
          .catchError((_) {});

      await user.delete();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        "/login",
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete Failed: $e")),
      );
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _auth.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  Future<void> updateStudentProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => isLoading = true);

    try {
      String? imageUrl = studentData?['profileImageUrl'];

      if (_selectedImage != null) {
        final ref = _storage.ref().child('students/$uid/profile.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      await _firestore.collection('students').doc(uid).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'bio': _bioController.text.trim(),
        'institution': _institutionController.text.trim(),
        'schoolName': _schoolController.text.trim(),
        'collegeName': _collegeController.text.trim(),
        'gender': gender,
        'studentClass': studentClass,
        'interestedSubjects': selectedSubjects,
        'profileImageUrl': imageUrl,
      }, SetOptions(merge: true));

      await fetchStudentData();

      if (!mounted) return;
      setState(() {
        isLoading = false;
        isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    }
  }

  ImageProvider? _buildProfileImageProvider() {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }

    final imageUrl = studentData?['profileImageUrl'];
    if (imageUrl != null &&
        imageUrl.toString().trim().isNotEmpty) {
      return NetworkImage(imageUrl);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E4C7A),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                setState(() => isEditing = true);
              } else if (value == 'logout') {
                _handleSignOut();
              } else if (value == 'delete') {
                _handleDeleteAccount();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text("Edit Profile"),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Text("Sign Out"),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  "Delete Account",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildModernHeader(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: isEditing ? _buildEditForm() : _buildProfileDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeader() {
    final imageProvider = _buildProfileImageProvider();

    return FadeInDown(
      child: Container(
        height: 220,
        decoration: const BoxDecoration(
          color: Color(0xFF1E4C7A),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(40),
            bottomRight: Radius.circular(40),
          ),
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 62,
                backgroundColor: Colors.white24,
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white,
                      )
                    : null,
              ),
              if (isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _pickProfileImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Color(0xFF1E4C7A),
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDetails() {
    return FadeInUp(
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoTile(Icons.person, "Name", _nameController.text),
              _buildInfoTile(Icons.phone, "Phone", _phoneController.text),
              _buildInfoTile(
                Icons.location_on,
                "Home Location",
                _locationController.text.isEmpty
                    ? "Not Added"
                    : _locationController.text,
              ),
              _buildInfoTile(
                Icons.people,
                "Gender",
                gender ?? "Not Added",
              ),
              _buildInfoTile(
                Icons.school,
                "Class",
                studentClass ?? "Not Added",
              ),
              _buildInfoTile(
                Icons.school_outlined,
                "School",
                _schoolController.text.isEmpty
                    ? "Not Added"
                    : _schoolController.text,
              ),
              _buildInfoTile(
                Icons.account_balance,
                "College",
                _collegeController.text.isEmpty
                    ? "Not Added"
                    : _collegeController.text,
              ),
              _buildInfoTile(
                Icons.business,
                "Institution",
                _institutionController.text.isEmpty
                    ? "Not Added"
                    : _institutionController.text,
              ),
              _buildInfoTile(
                Icons.info_outline,
                "Bio",
                _bioController.text.isEmpty
                    ? "Not Added"
                    : _bioController.text,
              ),
              const SizedBox(height: 20),
              const Text(
                "Interested Subjects",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              selectedSubjects.isEmpty
                  ? const Text("No Subjects Selected")
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedSubjects.map((subject) {
                        return Chip(
                          label: Text(subject),
                          backgroundColor: Colors.blue.shade50,
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Future payment screen
                  },
                  child: const Text("PAYMENT CONFIRMATION"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1E4C7A)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? "Not Added" : value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: "Full Name",
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: "Phone",
            prefixIcon: Icon(Icons.phone),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: "Home Location",
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(
          value: gender,
          decoration: const InputDecoration(
            labelText: "Gender",
            prefixIcon: Icon(Icons.people),
          ),
          items: const ["Male", "Female"]
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() => gender = v);
          },
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(
          value: studentClass,
          decoration: const InputDecoration(
            labelText: "Class",
            prefixIcon: Icon(Icons.school),
          ),
          items: classOptions
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() => studentClass = v);
          },
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _schoolController,
          decoration: const InputDecoration(
            labelText: "School Name",
            prefixIcon: Icon(Icons.school_outlined),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _collegeController,
          decoration: const InputDecoration(
            labelText: "College Name",
            prefixIcon: Icon(Icons.account_balance),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _institutionController,
          decoration: const InputDecoration(
            labelText: "Institution",
            prefixIcon: Icon(Icons.business),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _bioController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: "Bio",
            prefixIcon: Icon(Icons.info_outline),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "Interested Subjects",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: subjectOptions.map((subject) {
            final selected = selectedSubjects.contains(subject);

            return FilterChip(
              label: Text(subject),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    if (!selectedSubjects.contains(subject)) {
                      selectedSubjects.add(subject);
                    }
                  } else {
                    selectedSubjects.remove(subject);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    isEditing = false;
                    _selectedImage = null;
                  });
                  fetchStudentData();
                },
                child: const Text("Cancel"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
         