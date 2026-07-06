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
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _location = TextEditingController(),
      _bio = TextEditingController(),
      _institution = TextEditingController(),
      _school = TextEditingController(),
      _college = TextEditingController();

  Map<String, dynamic>? studentData;
  File? _selectedImage;
  bool isLoading = true, isEditing = false;
  String? gender, studentClass;
  List<String> selectedSubjects = [];

  final classOptions = const [
    'Class 1','Class 2','Class 3','Class 4','Class 5','Class 6',
    'Class 7','Class 8','Class 9','Class 10','Class 11','Class 12',
    'College','University','Others'
  ];

  final subjectOptions = const [
    "Mathematics","Physics","Chemistry","Biology",
    "English","Computer Science","History","Geography"
  ];

  @override
  void initState() {
    super.initState();
    fetchStudentData();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _location.dispose();
    _bio.dispose();
    _institution.dispose();
    _school.dispose();
    _college.dispose();
    super.dispose();
  }

  Future<void> fetchStudentData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return setState(() => isLoading = false);

    try {
      final data =
          (await _firestore.collection('students').doc(uid).get()).data() ?? {};
      if (!mounted) return;

      setState(() {
        studentData = data;
        _name.text = data['name'] ?? '';
        _phone.text = data['phone'] ?? '';
        _location.text = data['location'] ?? '';
        _bio.text = data['bio'] ?? '';
        _institution.text = data['institution'] ?? '';
        _school.text = data['schoolName'] ?? '';
        _college.text = data['collegeName'] ?? '';
        gender = data['gender'];
        studentClass = data['studentClass'];
        selectedSubjects = List<String>.from(data['interestedSubjects'] ?? []);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _snack('Failed to load profile: $e');
    }
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _handleDeleteAccount() async {
    final ok = await _confirm(
      'Delete Account',
      'This will permanently delete your account and all your data.\n\nAre you sure?',
      confirmText: 'Delete',
      danger: true,
    );
    if (ok != true) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final uid = user.uid;

      await _firestore.collection('students').doc(uid).delete();
      await _firestore.collection('usernames').doc(uid).delete().catchError((_) {});
      await _storage.ref('students/$uid/profile.jpg').delete().catchError((_) {});
      await user.delete();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (e) {
      _snack('Delete Failed: $e');
    }
  }

  Future<void> _handleSignOut() async {
    final ok = await _confirm('Sign Out', 'Are you sure you want to sign out?');
    if (ok != true) return;

    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> updateStudentProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => isLoading = true);

    try {
      String? imageUrl = studentData?['profileImageUrl'];

      if (_selectedImage != null) {
        final ref = _storage.ref('students/$uid/profile.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      await _firestore.collection('students').doc(uid).set({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'location': _location.text.trim(),
        'bio': _bio.text.trim(),
        'institution': _institution.text.trim(),
        'schoolName': _school.text.trim(),
        'collegeName': _college.text.trim(),
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
      _snack('Profile updated successfully');
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _snack('Update failed: $e');
    }
  }

  Future<bool?> _confirm(String title, String msg,
      {String confirmText = 'Confirm', bool danger = false}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: danger
                ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: TextStyle(color: danger ? Colors.white : null),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  ImageProvider? get _profileImage {
    if (_selectedImage != null) return FileImage(_selectedImage!);
    final url = studentData?['profileImageUrl'];
    return (url != null && url.toString().trim().isNotEmpty)
        ? NetworkImage(url)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E4C7A),
        foregroundColor: Colors.white,
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') setState(() => isEditing = true);
              if (v == 'logout') _handleSignOut();
              if (v == 'delete') _handleDeleteAccount();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit Profile')),
              PopupMenuItem(value: 'logout', child: Text('Sign Out')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete Account', style: TextStyle(color: Colors.red)),
              ),
            ],
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: isEditing ? _buildEditForm() : _buildProfileDetails(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() => FadeInDown(
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
                  backgroundImage: _profileImage,
                  child: _profileImage == null
                      ? const Icon(Icons.person, size: 60, color: Colors.white)
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
                        child: const Icon(Icons.camera_alt, color: Color(0xFF1E4C7A)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _buildProfileDetails() => FadeInUp(
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _info(Icons.person, "Name", _name.text),
                _info(Icons.phone, "Phone", _phone.text),
                _info(Icons.location_on, "Home Location", _location.text),
                _info(Icons.people, "Gender", gender ?? "Not Added"),
                _info(Icons.school, "Class", studentClass ?? "Not Added"),
                _info(Icons.school_outlined, "School", _school.text),
                _info(Icons.account_balance, "College", _college.text),
                _info(Icons.business, "Institution", _institution.text),
                _info(Icons.info_outline, "Bio", _bio.text),
                const SizedBox(height: 20),
                const Text("Interested Subjects",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                selectedSubjects.isEmpty
                    ? const Text("No Subjects Selected")
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedSubjects
                            .map((s) => Chip(
                                  label: Text(s),
                                  backgroundColor: Colors.blue.shade50,
                                ))
                            .toList(),
                      ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text("PAYMENT CONFIRMATION"),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _info(IconData icon, String title, String value) => Padding(
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
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(
                    value.trim().isEmpty ? "Not Added" : value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildEditForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(_name, "Full Name", Icons.person),
          _gap(),
          _field(_phone, "Phone", Icons.phone, type: TextInputType.phone),
          _gap(),
          _field(_location, "Home Location", Icons.location_on),
          _gap(),
          DropdownButtonFormField<String>(
            value: gender,
            decoration: const InputDecoration(
              labelText: "Gender",
              prefixIcon: Icon(Icons.people),
            ),
            items: const ['Male', 'Female']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => gender = v),
          ),
          _gap(),
          DropdownButtonFormField<String>(
            value: studentClass,
            decoration: const InputDecoration(
              labelText: "Class",
              prefixIcon: Icon(Icons.school),
            ),
            items: classOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => studentClass = v),
          ),
          _gap(),
          _field(_school, "School Name", Icons.school_outlined),
          _gap(),
          _field(_college, "College Name", Icons.account_balance),
          _gap(),
          _field(_institution, "Institution", Icons.business),
          _gap(),
          _field(_bio, "Bio", Icons.info_outline, maxLines: 4),
          const SizedBox(height: 20),
          const Text("Interested Subjects",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: subjectOptions.map((subject) {
              final selected = selectedSubjects.contains(subject);
              return FilterChip(
                label: Text(subject),
                selected: selected,
                onSelected: (v) => setState(() {
                  v
                      ? selectedSubjects.add(subject)
                      : selectedSubjects.remove(subject);
                  selectedSubjects = selectedSubjects.toSet().toList();
                }),
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
                child: ElevatedButton(
                  onPressed: updateStudentProfile,
                  child: const Text("Save Changes"),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) =>
      TextField(
        controller: c,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      );

  Widget _gap() => const SizedBox(height: 15);
}