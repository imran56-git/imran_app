import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_utils.dart';
import 'location_picker_screen.dart';

class TeacherProfileScreen extends StatefulWidget {
  final String? teacherId;
  const TeacherProfileScreen({super.key, this.teacherId});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? teacherData;
  bool isLoading = true, isEditing = false, isFollowing = false;
  File? _selectedImage;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _subjectSearchController = TextEditingController();

  String? gender;
  List<String> selectedSubjects = [];
  List<dynamic> teacherLocations = [];

  String get targetUID => widget.teacherId ?? _auth.currentUser?.uid ?? "";

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
      isFollowing ? await docRef.delete() : await docRef.set({
          'teacherId': widget.teacherId,
          'studentId': currentUID,
          'timestamp': FieldValue.serverTimestamp(),
        });
      checkFollowStatus();
    } catch (e) {
      debugPrint('$e');
    }
  }

  void _openMapPicker() async {
    final List<Map<String, dynamic>>? results = await Navigator.push(
      context, MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );
    if (results != null && results.isNotEmpty) {
      setState(() => teacherLocations.addAll(results));
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

  void _showAnimatedPopup({
    required String title,
    required String message,
    required String confirmText,
    required VoidCallback onConfirm,
    bool isDelete = false,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, a1, a2) => const SizedBox(),
      transitionBuilder: (context, anim, a2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: FadeTransition(
              opacity: anim,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                content: Text(message, style: const TextStyle(fontSize: 16, color: Colors.black87)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDelete ? Colors.red : Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPaymentDisabledPopup() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, a1, a2) => const SizedBox(),
      transitionBuilder: (context, anim, a2, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: FadeTransition(
            opacity: anim,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('This service is currently disabled.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 10),
                  Text('We are working on this feature.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  Text('It will be available in a future update.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Teacher Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [if (widget.teacherId == null) _buildMenu()],
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileImage(),
            const SizedBox(height: 15),
            _buildNameWithBadge(),
            const SizedBox(height: 8),
            if (!isEditing) _buildFollowStats(),
            if (widget.teacherId != null) _buildFollowButton(),
            const SizedBox(height: 25),
            isEditing ? _buildEditForm() : _buildViewProfile(),
            if (widget.teacherId == null && !isEditing) _buildToolsAndPayment(),
            if (isEditing) _buildSaveCancelButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (val) {
        if (val == 'edit') {
          setState(() => isEditing = true);
        } else if (val == 'signout') {
          _showAnimatedPopup(title: 'Sign Out', message: 'Are you sure?', confirmText: 'Confirm', onConfirm: () async => await _auth.signOut());
        } else if (val == 'delete') {
          _showAnimatedPopup(title: 'Delete Account', message: 'This will permanently delete your account.\nAre you sure?', confirmText: 'Delete', isDelete: true, onConfirm: () {});
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 10), Text('Edit Profile')])),
        const PopupMenuItem(value: 'signout', child: Row(children: [Icon(Icons.logout, size: 20, color: Colors.orange), SizedBox(width: 10), Text('Sign Out')])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, size: 20, color: Colors.red), SizedBox(width: 10), Text('Delete Account', style: TextStyle(color: Colors.red))])),
      ],
    );
  }

  Widget _buildProfileImage() {
    final url = teacherData?['profileImageUrl'];
    return GestureDetector(
      onTap: isEditing ? () async {
        final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (picked != null) setState(() => _selectedImage = File(picked.path));
      } : null,
      child: Stack(children: [
        CircleAvatar(radius: 65, backgroundColor: Colors.blue[50], backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : (url != null ? NetworkImage(url) : null) as ImageProvider?),
        if (isEditing) Positioned(bottom: 0, right: 0, child: CircleAvatar(backgroundColor: Colors.blue[800], radius: 20, child: const Icon(Icons.camera_alt, color: Colors.white, size: 18))),
      ]),
    );
  }

  Widget _buildNameWithBadge() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_nameController.text.isEmpty ? "No Name" : _nameController.text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      if (teacherData?['isVerified'] ?? false) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, color: Colors.blue, size: 22)),
    ]);
  }

  Widget _buildFollowStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('follows').where('teacherId', isEqualTo: targetUID).snapshots(),
      builder: (context, snap) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
        child: Text('Followers: ${snap.data?.docs.length ?? 0}', style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFollowButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: ElevatedButton.icon(
        onPressed: toggleFollow,
        icon: Icon(isFollowing ? Icons.check : Icons.person_add),
        label: Text(isFollowing ? 'Following' : 'Follow Teacher'),
        style: ElevatedButton.styleFrom(backgroundColor: isFollowing ? Colors.green : Colors.blue[800], foregroundColor: Colors.white, minimumSize: const Size(180, 45)),
      ),
    );
  }

  Widget _buildViewProfile() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoTile("Bio", _bioController.text, Icons.description_outlined),
      _infoTile("Teaching Class", _classController.text, Icons.school_outlined),
      _infoTile("Gender", gender ?? "Not set", Icons.wc_outlined),
      const SizedBox(height: 15),
      const Text("Teaching Areas (Locations)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: teacherLocations.map((l) => Chip(label: Text((l is Map) ? (l['address'] ?? "Unknown") : l.toString()), avatar: const Icon(Icons.location_on, size: 16))).toList()),
      const Divider(height: 30),
      const Text("Subjects", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: selectedSubjects.map((s) => Chip(label: Text(s), backgroundColor: Colors.blue[50])).toList()),
    ]);
  }

  Widget _buildEditForm() {
    final query = _subjectSearchController.text.trim();
    final list = _subjects.where((s) => s.toLowerCase().contains(query.toLowerCase())).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _editField("Full Name", _nameController, Icons.person),
      _editField("Bio", _bioController, Icons.info, maxLines: 3),
      _editField("Teaching Class", _classController, Icons.book),
      const Text("Add Teaching Areas", style: TextStyle(fontWeight: FontWeight.bold)),
      Wrap(spacing: 8, children: teacherLocations.map((loc) => Chip(label: Text((loc is Map) ? (loc['address'] ?? "Unknown") : loc.toString()), onDeleted: () => setState(() => teacherLocations.remove(loc)))).toList()),
      TextButton.icon(onPressed: _openMapPicker, icon: const Icon(Icons.map_outlined), label: const Text("Pick Locations")),
      const Divider(),
      const Text("Select Subjects", style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      TextField(
        controller: _subjectSearchController,
        decoration: InputDecoration(
          hintText: "Search subjects...", prefixIcon: const Icon(Icons.search),
          suffixIcon: (query.isNotEmpty && list.isEmpty) ? IconButton(icon: const Icon(Icons.add, color: Colors.green), onPressed: () {
            if (!selectedSubjects.contains(query)) { setState(() { selectedSubjects.add(query); _subjectSearchController.clear(); }); }
          }) : null,
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 10),
      SizedBox(height: 200, child: ListView(children: list.map((s) => CheckboxListTile(title: Text(s), value: selectedSubjects.contains(s), onChanged: (v) => setState(() => v! ? selectedSubjects.add(s) : selectedSubjects.remove(s)))).toList())),
    ]);
  }

  Widget _buildSaveCancelButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(children: [
        Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => setState(() => isEditing = false), child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))),
        const SizedBox(width: 10),
        Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 15)), onPressed: updateTeacherProfile, child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)))),
      ]),
    );
  }

  Widget _buildToolsAndPayment() {
    return Column(children: [
      const Divider(height: 40),
      Card(elevation: 2, child: ListTile(leading: const Icon(Icons.videocam, color: Colors.red), title: const Text("Go Live"), trailing: const Icon(Icons.chevron_right), onTap: () {})),
      const SizedBox(height: 12),
      Card(elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), child: ListTile(leading: const Icon(Icons.receipt_long, color: Colors.indigo, size: 28), title: const Text("Payment Confirmations", style: TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.chevron_right), onTap: _showPaymentDisabledPopup)),
    ]);
  }

  Widget _infoTile(String l, String v, IconData i) => ListTile(leading: Icon(i, color: Colors.blue[800]), title: Text(l, style: const TextStyle(fontSize: 12, color: Colors.grey)), subtitle: Text(v.isEmpty ? "Not set" : v, style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500)));
  Widget _editField(String l, TextEditingController c, IconData i, {int maxLines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 15), child: TextField(controller: c, maxLines: maxLines, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))))));
}

const List<String> _subjects = [
  'Bengali', 'English', 'Mathematics', 'General Science', 'Social Studies', 'ICT (Information & Tech)', 'Class1-8 all subjects', 'Physics', 'Chemistry', 'Biology', 'Higher Mathematics', 'Accounting', 'Business Studies', 'Finance & Banking', 'Geography & Environment', 'History', 'Civics & Citizenship', 'Economics', 'Physics 1st/2nd Paper', 'Chemistry 1st/2nd Paper', 'Biology 1st/2nd Paper', 'Higher Math 1st/2nd Paper', 'Statistics', 'Management', 'Marketing', 'Computer Science', 'App Development (Flutter)', 'Graphic Design', 'Cyber Security', 'Robotics', 'Data Science', 'UI/UX Design', 'Fine Arts', 'Music', 'Photography', 'Agriculture', 'IELTS/GRE Preparation'
];
