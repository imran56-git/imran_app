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

  final _name = TextEditingController(), _phone = TextEditingController(),
      _location = TextEditingController(), _bio = TextEditingController(),
      _institution = TextEditingController(), _school = TextEditingController(),
      _college = TextEditingController();

  Map<String, dynamic>? studentData;
  File? _selectedImage;
  bool isLoading = true, isEditing = false, _triggerAnimation = true;
  String? gender, studentClass;
  List<String> selectedSubjects = []; // 8. Strongly typed list for better quality

  final classOptions = const ['Class 1','Class 2','Class 3','Class 4','Class 5','Class 6','Class 7','Class 8','Class 9','Class 10','Class 11','Class 12','College','University','Others'];
  final subjectOptions = const ["Mathematics","Physics","Chemistry","Biology","English","Computer Science","History","Geography"];

  @override
  void initState() { super.initState(); fetchStudentData(); }

  @override
  void dispose() {
    for (var c in [_name, _phone, _location, _bio, _institution, _school, _college]) { c.dispose(); }
    super.dispose();
  }

  Future fetchStudentData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return setState(() => isLoading = false);
    try {
      final data = (await _firestore.collection('students').doc(uid).get()).data() ?? {};
      if (!mounted) return;
      setState(() {
        studentData = data;
        _name.text = data['name'] ?? ''; _phone.text = data['phone'] ?? '';
        _location.text = data['location'] ?? ''; _bio.text = data['bio'] ?? '';
        _institution.text = data['institution'] ?? ''; _school.text = data['schoolName'] ?? '';
        _college.text = data['collegeName'] ?? ''; gender = data['gender'];
        studentClass = data['studentClass']; selectedSubjects = List<String>.from(data['interestedSubjects'] ?? []);
        isLoading = false; _triggerAnimation = !_triggerAnimation; // 10. Toggle to refresh UI animation smoothly
      });
    } catch (e) { if (mounted) setState(() => isLoading = false); _snack('Failed to load profile: $e'); }
  }

  Future _pickProfileImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) setState(() => _selectedImage = File(picked.path));
  }

  // 7. Handle Delete Account with Re-authentication check
  Future _handleDeleteAccount() async {
    final ok = await confirm('Delete Account', 'This will permanently delete your account.\n\nAre you sure?', confirmText: 'Delete', danger: true);
    if (ok != true) return;
    try {
      final user = _auth.currentUser; if (user == null) return;
      final uid = user.uid;
      setState(() => isLoading = true);
      await _firestore.collection('students').doc(uid).delete();
      await _firestore.collection('usernames').doc(uid).delete().catchError((_) {});
      await _storage.ref('students/$uid/profile.jpg').delete().catchError((_) {});
      await user.delete();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (e) {
      setState(() => isLoading = false);
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        _snack('Security Error: Please logout and sign back in to delete your account.');
      } else { _snack('Delete Failed: $e'); }
    }
  }

  Future _handleSignOut() async {
    if (await confirm('Sign Out', 'Are you sure?') == true) {
      await _auth.signOut();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  Future updateStudentProfile() async {
    final uid = _auth.currentUser?.uid; if (uid == null) return;
    setState(() => isLoading = true);
    try {
      String? imageUrl = studentData?['profileImageUrl'];
      if (_selectedImage != null) {
        final ref = _storage.ref('students/$uid/profile.jpg');
        await ref.putFile(_selectedImage!); imageUrl = await ref.getDownloadURL();
      }
      await _firestore.collection('students').doc(uid).set({
        'name': _name.text.trim(), 'phone': _phone.text.trim(), 'location': _location.text.trim(),
        'bio': _bio.text.trim(), 'institution': _institution.text.trim(), 'schoolName': _school.text.trim(),
        'collegeName': _college.text.trim(), 'gender': gender, 'studentClass': studentClass,
        'interestedSubjects': selectedSubjects, 'profileImageUrl': imageUrl,
      }, SetOptions(merge: true));
      await fetchStudentData();
      if (mounted) setState(() { isEditing = false; });
      _snack('Profile updated successfully');
    } catch (e) { if (mounted) setState(() => isLoading = false); _snack('Update failed: $e'); }
  }

  Future<bool?> confirm(String title, String msg, {String confirmText = 'Confirm', bool danger = false}) {
    return showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(style: danger ? ElevatedButton.styleFrom(backgroundColor: Colors.red) : null,
          onPressed: () => Navigator.pop(ctx, true), child: Text(confirmText, style: TextStyle(color: danger ? Colors.white : null))),
      ],
    ));
  }

  void _snack(String msg) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); }

  ImageProvider? get _profileImage {
    if (_selectedImage != null) return FileImage(_selectedImage!);
    final url = studentData?['profileImageUrl'];
    return (url != null && url.toString().trim().isNotEmpty) ? NetworkImage(url) : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E4C7A), foregroundColor: Colors.white, elevation: 0,
        title: const Text('Student Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          // 6. Settings Screen Functional Navigation 
          IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.pushNamed(context, '/settings')),
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'edit') setState(() => isEditing = true); if (v == 'logout') _handleSignOut(); if (v == 'delete') _handleDeleteAccount(); },
            itemBuilder: (ctx) => const [PopupMenuItem(value: 'edit', child: Text('Edit Profile')), PopupMenuItem(value: 'logout', child: Text('Sign Out')), PopupMenuItem(value: 'delete', child: Text('Delete Account', style: TextStyle(color: Colors.red)))],
          )
        ],
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400), // 10. Smooth profile refresh transition effect
          child: Column(key: ValueKey(_triggerAnimation), children: [
            _buildHeader(), 
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: isEditing ? _buildEditForm() : _buildProfileDetails())
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() => FadeInDown(
    child: Container(
      width: double.infinity, padding: const EdgeInsets.only(bottom: 30, top: 10),
      decoration: const BoxDecoration(color: Color(0xFF1E4C7A), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35))),
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          CircleAvatar(radius: 55, backgroundColor: const Color(0xFFA2E8DD), backgroundImage: _profileImage, child: _profileImage == null ? const Icon(Icons.person, size: 65, color: Colors.white) : null),
          if (isEditing) Positioned(bottom: 0, right: 0, child: InkWell(onTap: _pickProfileImage, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: const Icon(Icons.camera_alt, color: Color(0xFF1E4C7A), size: 20)))),
        ]),
        const SizedBox(height: 15),
        Text(_name.text.isEmpty ? "No Name Added" : _name.text, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(_bio.text.isEmpty ? "No Bio Added" : _bio.text, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
      ]),
    ),
  );

  Widget _buildCard(IconData icon, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(children: [Icon(icon, color: Colors.black87, size: 24), const SizedBox(height: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87))]),
    ),
  );

  Widget _buildProfileDetails() => FadeInUp(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 15),
      Row(children: [_buildCard(Icons.school, studentClass ?? "Not Added"), const SizedBox(width: 15), _buildCard(Icons.location_on, _location.text.isEmpty ? "Not Added" : _location.text)]),
      const SizedBox(height: 25),
      const Text("Interested Subjects", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      const SizedBox(height: 12),
      selectedSubjects.isEmpty ? const Text("No Subjects Selected", style: TextStyle(color: Colors.grey)) : Wrap(spacing: 10, runSpacing: 10, children: selectedSubjects.map((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)), child: Text(s, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)))).toList()),
      const SizedBox(height: 30),
      // 5. Payment Screen Navigation Added
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E7A6E), elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: Colors.grey.shade300))), onPressed: () => Navigator.pushNamed(context, '/payment_confirmation'), child: const Text("UPLOAD PAYMENT CONFIRMATION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))),
      const SizedBox(height: 25),
      Container(
        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          _info(Icons.person_outline, "Name", _name.text), const Divider(height: 1),
          _info(Icons.wc_outlined, "Gender", gender ?? "Not Added"), const Divider(height: 1),
          _info(Icons.school_outlined, "Class", studentClass ?? "Not Added"), const Divider(height: 1), // 4. Class Re-added here
          _info(Icons.history_edu_outlined, "School", _school.text), const Divider(height: 1),
          _info(Icons.account_balance_outlined, "College", _college.text), const Divider(height: 1),
          _info(Icons.business_outlined, "Institution", _institution.text), const Divider(height: 1),
          _info(Icons.map_outlined, "Home Location", _location.text), const Divider(height: 1), // 3. Home Location Re-added here
          _info(Icons.info_outline, "Bio", _bio.text), // 2. Bio Card Info Re-added here
          // 1. Note: Phone field is totally hidden from this Profile View details block as requested
        ]),
      ),
      const SizedBox(height: 20),
    ]),
  );

  Widget _info(IconData icon, String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [Icon(icon, color: const Color(0xFF1E4C7A), size: 22), const SizedBox(width: 15), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 2), Text(value.isEmpty ? "Not Added" : value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87))])]),
  );

  Widget _buildEditForm() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 10),
    _field(_name, "Full Name", Icons.person), _gap(),
    _field(_phone, "Phone", Icons.phone, type: TextInputType.phone), _gap(), // Available and saves to firebase securely
    _field(_location, "Home Location", Icons.location_on), _gap(),
    _dropDown("Gender", Icons.people, gender, ['Male', 'Female'], (v) => setState(() => gender = v)), _gap(),
    _dropDown("Class", Icons.school, studentClass, classOptions, (v) => setState(() => studentClass = v)), _gap(),
    _field(_school, "School Name", Icons.school_outlined), _gap(),
    _field(_college, "College Name", Icons.account_balance), _gap(),
    _field(_institution, "Institution", Icons.business), _gap(),
    _field(_bio, "Bio", Icons.info_outline, maxLines: 3),
    const SizedBox(height: 20),
    const Text("Interested Subjects", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    const SizedBox(height: 10),
    Wrap(spacing: 8, runSpacing: 8, children: subjectOptions.map((subject) => FilterChip(label: Text(subject), selected: selectedSubjects.contains(subject), onSelected: (v) => setState(() { v ? selectedSubjects.add(subject) : selectedSubjects.remove(subject); selectedSubjects = selectedSubjects.toSet().toList(); }))).toList()),
    const SizedBox(height: 30),
    Row(children: [Expanded(child: OutlinedButton(onPressed: () { setState(() { isEditing = false; _selectedImage = null; }); fetchStudentData(); }, child: const Text("Cancel"))), const SizedBox(width: 12), Expanded(child: ElevatedButton(onPressed: updateStudentProfile, child: const Text("Save Changes")))]),
    const SizedBox(height: 25),
  ]);

  Widget _dropDown(String label, IconData icon, String? value, List<String> items, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(value: value, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged);
  
  // 9. Premium Input Styling with Rounded Borders and Filled Background
  Widget _field(TextEditingController c, String lbl, IconData i, {TextInputType type = TextInputType.text, int maxLines = 1}) => TextField(
    controller: c, keyboardType: type, maxLines: maxLines, 
    decoration: InputDecoration(
      labelText: lbl, prefixIcon: Icon(i), filled: true, fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E4C7A), width: 1.5)),
    )
  );
  Widget _gap() => const SizedBox(height: 15);
}
