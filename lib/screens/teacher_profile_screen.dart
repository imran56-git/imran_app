import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
    // Science
    'Mathematics', 'Physics', 'Chemistry', 'Biology', 'Computer Science', 
    'Higher Math', 'General Science', 'Statistics',
    
    // Arts & Languages
    'English', 'Bengali', 'Hindi', 'Arabic', 'History', 'Geography', 
    'Political Science', 'Economics', 'Philosophy', 'Sociology', 'Sanskrit',
    
    // Commerce
    'Accounting', 'Business Studies', 'Finance', 'Marketing',
    
    // Tech & Skills
    'Web Development', 'App Development (Flutter)', 'Graphics Design', 
    'Digital Marketing', 'Video Editing', 'Python Programming', 'C/C++',
    
    // Others
    'Music', 'Drawing', 'Physical Education', 'General Knowledge'
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
      if (doc.exists) {
        teacherData = doc.data();
        _nameController.text = teacherData?['name'] ?? '';
        _phoneController.text = teacherData?['phone'] ?? '';
        _locationController.text = teacherData?['currentLocation'] ?? '';
        _classController.text = teacherData?['class'] ?? '';
        _bioController.text = teacherData?['bio'] ?? '';
        gender = teacherData?['gender'];
        selectedSubjects = List<String>.from(teacherData?['subjects'] ?? []);
        teacherLocations = teacherData?['locations'] ?? [];
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
    }
    if (mounted) setState(() => isLoading = false);
  }

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
  }

  Future<void> updateTeacherProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    setState(() => isLoading = true);
    try {
      String? imageUrl = teacherData?['profileImageUrl'];
      if (_selectedImage != null) {
        final ref = _storage.ref().child('teachers/$uid/profile.jpg');
        await ref.putFile(_selectedImage!);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated!')));
      setState(() => isEditing = false);
      fetchTeacherData();
    } catch (e) { debugPrint('Update error: $e'); }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = teacherData?['profileImageUrl'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Profile'),
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
            const SizedBox(height: 10),
            _buildNameWithBadge(),
            if (!isEditing) _buildFollowStats(),
            if (widget.teacherId != null) _buildFollowButton(),
            const SizedBox(height: 20),
            isEditing ? _buildEditForm() : _buildViewProfile(),
            if (widget.teacherId == null && !isEditing) _buildTeacherTools(),
            if (isEditing) Padding(
              padding: const EdgeInsets.only(top: 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                onPressed: updateTeacherProfile,
                child: const Text("SAVE CHANGES"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage(String? photoUrl) {
    return GestureDetector(
      onTap: isEditing ? () async {
        final picked = await _picker.pickImage(source: ImageSource.gallery);
        if (picked != null) setState(() => _selectedImage = File(picked.path));
      } : null,
      child: CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[200],
        backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : 
                        (photoUrl != null ? NetworkImage(photoUrl) : null) as ImageProvider?,
        child: photoUrl == null && _selectedImage == null ? const Icon(Icons.camera_alt, size: 40) : null,
      ),
    );
  }

  Widget _buildNameWithBadge() {
    bool isVerified = teacherData?['isVerified'] ?? false;
    bool hasSpecialBadge = teacherData?['hasSpecialBadge'] ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_nameController.text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        if (isVerified)
          const Padding(
            padding: EdgeInsets.only(left: 5),
            child: Icon(Icons.check_circle, color: Colors.blue, size: 20),
          ),
        if (hasSpecialBadge)
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Image.asset(
              'assets/images/special_badge.png',
              height: 25,
              width: 25,
            ),
          ),
      ],
    );
  }

  Widget _buildFollowStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('follows').where('teacherId', isEqualTo: targetUID).snapshots(),
      builder: (context, snapshot) {
        return Text('Followers: ${snapshot.data?.docs.length ?? 0}', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold));
      },
    );
  }

  Widget _buildFollowButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ElevatedButton.icon(
        onPressed: toggleFollow,
        icon: Icon(isFollowing ? Icons.person_remove : Icons.person_add, color: Colors.white),
        label: Text(isFollowing ? 'My Teacher' : 'Follow'),
        style: ElevatedButton.styleFrom(backgroundColor: isFollowing ? Colors.green : Colors.blue),
      ),
    );
  }

  Widget _buildViewProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoTile("Bio", _bioController.text, Icons.info_outline),
        _infoTile("Location", _locationController.text, Icons.location_on_outlined),
        _infoTile("Teaching Class", _classController.text, Icons.school_outlined),
        _infoTile("Gender", gender ?? "Not set", Icons.wc),
        const Divider(),
        const Text("Subjects", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Wrap(spacing: 8, children: selectedSubjects.map((s) => Chip(label: Text(s))).toList()),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        _editField("Full Name", _nameController),
        _editField("Phone", _phoneController),
        _editField("Home Location", _locationController),
        _editField("Class", _classController),
        _editField("Bio", _bioController, maxLines: 3),
        DropdownButtonFormField<String>(
          value: gender,
          decoration: const InputDecoration(labelText: "Gender"),
          items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (val) => setState(() => gender = val),
        ),
        const SizedBox(height: 20),
        const Align(alignment: Alignment.centerLeft, child: Text("Select Subjects", style: TextStyle(fontWeight: FontWeight.bold))),
        TextField(
          controller: _subjectSearchController,
          decoration: const InputDecoration(hintText: "Search..."),
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

  Widget _buildTeacherTools() {
    return Column(
      children: [
        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
        _toolTile(Icons.videocam, "Go Live", Colors.red, () {}),
        _toolTile(Icons.schedule, "Fee Reminder", Colors.teal, () {}),
        _toolTile(Icons.payment, "Edit UPI ID", Colors.orange, () {}),
        _toolTile(Icons.receipt_long, "Payment Confirmations", Colors.indigo, () {}),
      ],
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent), 
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), 
      subtitle: Text(value.isEmpty ? "N/A" : value, style: const TextStyle(fontSize: 16, color: Colors.black))
    );
  }

  Widget _editField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10), 
      child: TextField(controller: controller, maxLines: maxLines, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()))
    );
  }

  Widget _toolTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return Card(child: ListTile(leading: Icon(icon, color: color), title: Text(label), trailing: const Icon(Icons.arrow_forward_ios, size: 16), onTap: onTap));
  }
}
