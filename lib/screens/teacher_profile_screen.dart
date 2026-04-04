import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_utils.dart';

class TeacherProfileScreen extends StatefulWidget {
  final String? teacherId;
  const TeacherProfileScreen({super.key, this.teacherId});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? teacherData;
  bool isLoading = true;
  bool isEditing = false;
  bool isFollowing = false;
  File? _selectedImage;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _subjectSearchController = TextEditingController();

  String? gender;
  List<String> selectedSubjects = [];
  List<dynamic> teacherLocations = []; 

  String get targetUID => widget.teacherId ?? _auth.currentUser?.uid ?? "";

    final List<String> allSubjects = [
    // --- Primary & Junior (Class 1 - 8) ---
    'Bengali', 'English', 'Mathematics', 'General Science', 'Social Studies',
    'Religion & Moral Education', 'ICT (Information & Tech)', 'Physical Education',
    'Arts and Crafts', 'Work and Life Oriented Education', 'Global Studies',

    // --- High School (Class 9 - 10) ---
    // Science
    'Physics', 'Chemistry', 'Biology', 'Higher Mathematics',
    // Commerce
    'Accounting', 'Business Studies', 'Finance & Banking',
    // Arts
    'Geography & Environment', 'History', 'Civics & Citizenship', 'Economics',

    // --- Higher Secondary (Class 11 - 12 / College) ---
    // Science
    'Physics 1st/2nd Paper', 'Chemistry 1st/2nd Paper', 'Biology 1st/2nd Paper', 
    'Higher Math 1st/2nd Paper', 'Statistics',
    // Commerce
    'Management', 'Marketing', 'Production Management', 'Commercial Law',
    // Arts
    'Logic', 'Sociology', 'Social Work', 'Psychology', 'Islamic History',
    'Philosophy', 'Political Science', 'Sanskrit', 'Home Science',

    // --- University & Professional Course ---
    // Technology & IT
    'Computer Science', 'Programming (C/C++, Python, Java)', 'Data Structure',
    'Web Development', 'App Development (Flutter)', 'Graphic Design',
    'Digital Marketing', 'Cyber Security', 'Artificial Intelligence',
    'Robotics', 'Data Science', 'Machine Learning', 'UI/UX Design',
    // Engineering
    'Mechanical Engineering', 'Electrical Engineering', 'Civil Engineering',
    'Software Engineering', 'Textile Engineering',
    // Medical
    'Anatomy', 'Physiology', 'Biochemistry', 'Microbiology', 'Pharmacy',
    // Business & Professional
    'BBA', 'MBA', 'Human Resource (HRM)', 'Supply Chain Management',
    'Chartered Accountancy (CA)', 'Public Speaking', 'Legal Studies (Law)',

    // --- Language Learning ---
    'Arabic', 'Hindi', 'Urdu', 'French', 'German', 'Japanese', 'Chinese', 'Spanish',

    // --- Creative & Vocational ---
    'Fine Arts', 'Music (Vocal)', 'Music (Instrumental)', 'Dance', 'Photography',
    'Video Editing', 'Interior Design', 'Fashion Design', 'Agriculture',
    'General Knowledge (GK)', 'Current Affairs', 'IELTS/GRE Preparation',
  ];

  @override
  void initState() {
    super.initState();
    fetchTeacherData();
    checkFollowStatus();
  }

  Future<void> fetchTeacherData() async {
    if (targetUID.isEmpty) return;
    try {
      final doc = await _firestore.collection('teachers').doc(targetUID).get();
      if (doc.exists && mounted) {
        setState(() {
          teacherData = doc.data();
          _nameController.text = teacherData?['name'] ?? '';
          _phoneController.text = teacherData?['phone'] ?? '';
          _locationController.text = teacherData?['currentLocation'] ?? '';
          _classController.text = teacherData?['class'] ?? '';
          _bioController.text = teacherData?['bio'] ?? '';
          gender = teacherData?['gender'];
          selectedSubjects = List<String>.from(teacherData?['subjects'] ?? []);
          teacherLocations = List.from(teacherData?['locations'] ?? []);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- Follow Logic ---
  void checkFollowStatus() async {
    final currentUID = _auth.currentUser?.uid;
    if (currentUID == null || widget.teacherId == null) return;
    final doc = await _firestore.collection('follows').doc('${currentUID}_${widget.teacherId}').get();
    if (mounted) setState(() => isFollowing = doc.exists);
  }

  void toggleFollow() async {
    final currentUID = _auth.currentUser?.uid;
    if (currentUID == null || widget.teacherId == null) return;
    final docRef = _firestore.collection('follows').doc('${currentUID}_${widget.teacherId}');
    try {
      if (isFollowing) {
        await docRef.delete();
      } else {
        await docRef.set({
          'teacherId': widget.teacherId,
          'studentId': currentUID,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      checkFollowStatus();
    } catch (e) {
      debugPrint('Follow error: $e');
    }
  }

  Future<void> updateTeacherProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    setState(() => isLoading = true);
    try {
      String? imageUrl = teacherData?['profileImageUrl'];
      if (_selectedImage != null) {
        File? compressedFile = await ImageHelper.compressImage(_selectedImage!);
        final ref = _storage.ref().child('teachers/$uid/profile.jpg');
        await ref.putFile(compressedFile ?? _selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      await _firestore.collection('teachers').doc(uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'currentLocation': _locationController.text.trim(),
        'class': _classController.text.trim(),
        'bio': _bioController.text.trim(),
        'gender': gender,
        'profileImageUrl': imageUrl,
        'subjects': selectedSubjects,
        'locations': teacherLocations,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated!')));
        setState(() => isEditing = false);
        fetchTeacherData();
      }
    } catch (e) { 
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = teacherData?['profileImageUrl'];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Teacher Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          if (widget.teacherId == null)
            IconButton(
              icon: Icon(isEditing ? Icons.close : Icons.edit),
              onPressed: () => setState(() => isEditing = !isEditing),
            )
        ],
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileImage(photoUrl),
            const SizedBox(height: 15),
            _buildNameWithBadge(),
            if (!isEditing) _buildFollowStats(),
            if (widget.teacherId != null) _buildFollowButton(),
            const SizedBox(height: 25),
            isEditing ? _buildEditForm() : _buildViewProfile(),
            if (widget.teacherId == null && !isEditing) _buildTeacherTools(),
            if (isEditing) _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(String? photoUrl) {
    return Center(
      child: GestureDetector(
        onTap: isEditing ? () async {
          final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
          if (picked != null) setState(() => _selectedImage = File(picked.path));
        } : null,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 65,
              backgroundColor: Colors.blue[50],
              backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : 
                              (photoUrl != null ? NetworkImage(photoUrl) : null) as ImageProvider?,
              child: photoUrl == null && _selectedImage == null ? Icon(Icons.person, size: 60, color: Colors.blue[800]) : null,
            ),
            if (isEditing) Positioned(bottom: 0, right: 0, child: CircleAvatar(backgroundColor: Colors.blue[800], radius: 20, child: const Icon(Icons.camera_alt, color: Colors.white, size: 18))),
          ],
        ),
      ),
    );
  }

  Widget _buildNameWithBadge() {
    bool isVerified = teacherData?['isVerified'] ?? false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_nameController.text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        if (isVerified) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, color: Colors.blue, size: 22)),
      ],
    );
  }

  Widget _buildFollowStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('follows').where('teacherId', isEqualTo: targetUID).snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.data?.docs.length ?? 0;
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
          child: Text('Followers: $count', style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildFollowButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: ElevatedButton.icon(
        onPressed: toggleFollow,
        icon: Icon(isFollowing ? Icons.check : Icons.person_add),
        label: Text(isFollowing ? 'Following' : 'Follow Teacher'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing ? Colors.green : Colors.blue[800],
          foregroundColor: Colors.white,
          minimumSize: const Size(180, 45)
        ),
      ),
    );
  }

  Widget _buildViewProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoTile("Bio", _bioController.text, Icons.description_outlined),
        _infoTile("Teaching Class", _classController.text, Icons.school_outlined),
        _infoTile("Gender", gender ?? "Not set", Icons.wc_outlined),
        const SizedBox(height: 15),
        const Text("Teaching Areas (Locations)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: teacherLocations.map((l) => Chip(label: Text(l), avatar: const Icon(Icons.location_on, size: 16))).toList()),
        const Divider(height: 30),
        const Text("Subjects", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: selectedSubjects.map((s) => Chip(label: Text(s), backgroundColor: Colors.blue[50])).toList()),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _editField("Full Name", _nameController, Icons.person),
        _editField("Bio", _bioController, Icons.info, maxLines: 3),
        _editField("Teaching Class", _classController, Icons.book),
        
        // --- MULTIPLE LOCATION SECTION ---
        const Text("Add Teaching Areas", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: teacherLocations.map((loc) => Chip(
            label: Text(loc),
            onDeleted: () => setState(() => teacherLocations.remove(loc)),
          )).toList(),
        ),
        TextButton.icon(
          onPressed: _addLocationDialog,
          icon: const Icon(Icons.add_location_alt),
          label: const Text("Add New Location"),
        ),
        const Divider(),
        
        // --- SUBJECT SEARCH SECTION ---
        const Text("Select Subjects", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _subjectSearchController,
          decoration: const InputDecoration(hintText: "Search subjects...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(
          height: 200,
          child: ListView(
            children: allSubjects.where((s) => s.toLowerCase().contains(_subjectSearchController.text.toLowerCase()))
              .map((s) => CheckboxListTile(
                title: Text(s),
                value: selectedSubjects.contains(s),
                onChanged: (val) => setState(() { val! ? selectedSubjects.add(s) : selectedSubjects.remove(s); }),
              )).toList(),
          ),
        ),
      ],
    );
  }

  void _addLocationDialog() {
    TextEditingController lCon = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Add Area"),
      content: TextField(controller: lCon, decoration: const InputDecoration(hintText: "e.g. Dhanmondi, Dhaka")),
      actions: [TextButton(onPressed: () {
        if(lCon.text.isNotEmpty) setState(() => teacherLocations.add(lCon.text.trim()));
        Navigator.pop(c);
      }, child: const Text("Add"))],
    ));
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55)),
        onPressed: updateTeacherProfile,
        child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTeacherTools() {
    return Column(
      children: [
        const Divider(height: 40),
        _toolTile(Icons.videocam, "Go Live", Colors.red, () {}),
        _toolTile(Icons.receipt_long, "Payment Confirmations", Colors.indigo, () {}),
      ],
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[800]), 
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), 
      subtitle: Text(value.isEmpty ? "N/A" : value, style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500))
    );
  }

  Widget _editField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15), 
      child: TextField(
        controller: controller, 
        maxLines: maxLines, 
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))))
      )
    );
  }

  Widget _toolTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: Icon(icon, color: color), title: Text(label), trailing: const Icon(Icons.chevron_right), onTap: onTap));
  }
}
