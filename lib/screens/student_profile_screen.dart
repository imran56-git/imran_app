import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

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
      _college = TextEditingController(),
      _customSubjectController = TextEditingController(); 

  Map<String, dynamic>? studentData;
  File? _selectedImage;
  bool isLoading = true, isEditing = false, _triggerAnimation = true;
  String? gender, studentClass;
  List<String> selectedSubjects = []; 

  final classOptions = const ['Class 1','Class 2','Class 3','Class 4','Class 5','Class 6','Class 7','Class 8','Class 9','Class 10','Class 11','Class 12','College','University','Others'];
  final subjectOptions = const ["Mathematics","Physics","Chemistry","Biology","English","Computer Science","History","Geography"];

  @override
  void initState() { super.initState(); fetchStudentData(); }

  @override
  void dispose() {
    for (var c in [_name, _phone, _location, _bio, _institution, _school, _college, _customSubjectController]) { c.dispose(); }
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
        isLoading = false; 
        _triggerAnimation = !_triggerAnimation; 
      });
    } catch (e) { 
      if (mounted) setState(() => isLoading = false); 
      _snack('Failed to load profile: $e', isError: true); 
    }
  }

  Future _pickProfileImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null && mounted) setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
  }

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

      await _clearLocalSession(); 
      await user.delete();

      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (e) {
      setState(() => isLoading = false);
      if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
        _snack('Security Error: Please logout and sign back in to delete your account.', isError: true);
      } else { _snack('Delete Failed: $e', isError: true); }
    }
  }

  Future _handleSignOut() async {
    if (await confirm('Sign Out', 'Are you sure?') == true) {
      setState(() => isLoading = true);
      await _auth.signOut();
      await _clearLocalSession(); 
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

      if (mounted) {
        setState(() { 
          isEditing = false; 
        });
      }
      await fetchStudentData();
      _snack('Profile updated successfully', isError: false);
    } catch (e) { if (mounted) setState(() => isLoading = false); _snack('Update failed: $e', isError: true); }
  }

  Future<bool?> confirm(String title, String msg, {String confirmText = 'Confirm', bool danger = false}) {
    return showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: danger ? Colors.redAccent : const Color(0xFF1E4C7A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
          ),
          onPressed: () => Navigator.pop(ctx, true), 
          child: Text(confirmText)
        ),
      ],
    ));
  }

  void _showServiceUnavailableDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Service Unavailable', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This service is currently disabled.\n\nIt will be available in a future update.\nThank you for your patience.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK', style: TextStyle(color: Color(0xFF1E4C7A)))),
        ],
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) { 
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
          backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )
      ); 
    } 
  }

  ImageProvider? get _profileImage {
    if (_selectedImage != null) return FileImage(_selectedImage!);
    final url = studentData?['profileImageUrl'];
    return (url != null && url.toString().trim().isNotEmpty) ? NetworkImage(url) : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E4C7A), 
        foregroundColor: Colors.white, 
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false, 
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.school_rounded, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'FYBTT', 
              style: TextStyle(fontWeight: FontWeight.black, fontSize: 19, letterSpacing: 0.5)
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (v) { 
              if (v == 'edit') setState(() { isEditing = true; _triggerAnimation = !_triggerAnimation; }); 
              if (v == 'logout') _handleSignOut(); 
              if (v == 'delete') _handleDeleteAccount(); 
              if (v == 'payment') _showServiceUnavailableDialog();
            },
            itemBuilder: (ctx) => [
              // বাগ ফিক্স: Colors.black70 এর বদলে সঠিক Colors.black54 ব্যবহার করা হলো এবং কনস্ট্যান্ট ঠিক করা হলো
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18, color: Colors.black54), SizedBox(width: 10), Text('Edit Profile')])), 
              const PopupMenuItem(value: 'payment', child: Row(children: [Icon(Icons.payment_rounded, size: 18, color: Colors.black54), SizedBox(width: 10), Text('Payment Ticket')])), 
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout_rounded, size: 18, color: Colors.black54), SizedBox(width: 10), Text('Sign Out')])), 
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever_rounded, size: 18, color: Colors.redAccent), SizedBox(width: 10), Text('Delete Account', style: TextStyle(color: Colors.redAccent))])),
            ],
          )
        ],
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A), strokeWidth: 3.5)) : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350), 
          child: Column(key: ValueKey(_triggerAnimation), children: [
            _buildHeader(), 
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: isEditing ? _buildEditForm() : _buildProfileDetails())
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final currentUid = _auth.currentUser?.uid ?? 'N/A';

    return FadeInDown(
      duration: const Duration(milliseconds: 400),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.only(bottom: 25, top: 10),
        decoration: const BoxDecoration(color: Color(0xFF1E4C7A), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(35), bottomRight: Radius.circular(35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                'My Profile', 
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.3)
              ),
            ),
          ),
          const SizedBox(height: 15),
          Stack(alignment: Alignment.center, children: [
            CircleAvatar(radius: 52, backgroundColor: const Color(0xFFA2E8DD), backgroundImage: _profileImage, child: _profileImage == null ? const Icon(Icons.person_rounded, size: 60, color: Colors.white) : null),
            if (isEditing) Positioned(bottom: 0, right: 0, child: InkWell(onTap: _pickProfileImage, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF1E4C7A), size: 18)))),
          ]),
          const SizedBox(height: 14),
          Text(_name.text.isEmpty ? "No Name Added" : _name.text, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_bio.text.isEmpty ? "No Bio Added" : _bio.text, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 18),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("REGISTRATION ID / UID", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(
                          currentUid,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: currentUid));
                      _snack("ID Copied to Clipboard!");
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.copy_all_rounded, color: Color(0xFFA2E8DD), size: 18),
                    ),
                  )
                ],
              ),
            ),
          )
        ]),
      ),
    );
  }

  Widget _buildCard(IconData icon, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(children: [Icon(icon, color: const Color(0xFF1E4C7A), size: 24), const SizedBox(height: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,)]),
    ),
  );

  Widget _buildProfileDetails() => FadeInUp(
    duration: const Duration(milliseconds: 400),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      Row(children: [_buildCard(Icons.school_rounded, studentClass ?? "Not Added"), const SizedBox(width: 14), _buildCard(Icons.location_on_rounded, _location.text.isEmpty ? "Not Added" : _location.text)]),
      const SizedBox(height: 25),
      const Text("Interested Subjects", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B1B1B))),
      const SizedBox(height: 12),
      selectedSubjects.isEmpty ? const Text("No Subjects Selected", style: TextStyle(color: Colors.grey, fontSize: 13)) : Wrap(spacing: 8, runSpacing: 8, children: selectedSubjects.map((s) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)), child: Text(s, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)))).toList()),
      const SizedBox(height: 25),
      Container(
        padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.1))),
        child: Column(children: [
          _info(Icons.person_outline_rounded, "Name", _name.text), const Divider(height: 1, color: Color(0xFFF1F3F5)),
          _info(Icons.wc_outlined, "Gender", gender ?? "Not Added"), const Divider(height: 1, color: Color(0xFFF1F3F5)),
          _info(Icons.phone_android_rounded, "Phone", _phone.text), const Divider(height: 1, color: Color(0xFFF1F3F5)),
          _info(Icons.school_outlined, "Class/Grade", studentClass ?? "Not Added"), const Divider(height: 1, color: Color(0xFFF1F3F5)), 
          _info(Icons.history_edu_rounded, "School Name", _school.text), const Divider(height: 1, color: Color(0xFFF1F3F5)),
          _info(Icons.account_balance_rounded, "College Name", _college.text), const Divider(height: 1, color: Color(0xFFF1F3F5)),
          _info(Icons.business_rounded, "Tuition Institution", _institution.text), const Divider(height: 1, color: Color(0xFFF1F3F5)),
          _info(Icons.map_rounded, "Home Location", _location.text), 
        ]),
      ),
      const SizedBox(height: 25),
    ]),
  );
  Widget _info(IconData icon, String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF1E4C7A), size: 22), 
      const SizedBox(width: 16), 
      Expanded( 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500)), 
            const SizedBox(height: 3), 
            Text(value.isEmpty ? "Not Added" : value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87))
          ]
        ),
      )
    ]),
  );

  Widget _buildEditForm() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 10),
    _field(_name, "Full Name", Icons.person_rounded), _gap(),
    _field(_phone, "Phone Number", Icons.phone_rounded, type: TextInputType.phone), _gap(), 
    _field(_location, "Home Location", Icons.location_on_rounded), _gap(),
    _dropDown("Select Gender", Icons.people_rounded, gender, ['Male', 'Female'], (v) => setState(() => gender = v)), _gap(),
    _dropDown("Select Class", Icons.school_rounded, studentClass, classOptions, (v) => setState(() => studentClass = v)), _gap(),
    _field(_school, "School Name", Icons.school_outlined), _gap(),
    _field(_college, "College Name", Icons.account_balance_rounded), _gap(),
    _field(_institution, "Tuition Institution", Icons.business_rounded), _gap(),
    _field(_bio, "Write Biography", Icons.info_outline_rounded, maxLines: 3),
    const SizedBox(height: 25),
    const Text("Interested Subjects", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B1B1B))),
    const SizedBox(height: 12),

    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _customSubjectController,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: "Enter Custom Subject (e.g., Bengali)",
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E4C7A), width: 1.5)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 48,
          child: IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF1E4C7A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              final txt = _customSubjectController.text.trim();
              if (txt.isNotEmpty) {
                if (!selectedSubjects.contains(txt)) { setState(() { selectedSubjects.add(txt); }); }
                _customSubjectController.clear();
              }
            },
          ),
        ),
      ],
    ),
    const SizedBox(height: 15),

    Wrap(
      spacing: 8, runSpacing: 8, 
      children: [
        ...subjectOptions.map((subject) => FilterChip(
          label: Text(subject), 
          selected: selectedSubjects.contains(subject), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          selectedColor: const Color(0xFFA2E8DD).withOpacity(0.3),
          checkmarkColor: const Color(0xFF1E4C7A),
          onSelected: (v) => setState(() { v ? selectedSubjects.add(subject) : selectedSubjects.remove(subject); selectedSubjects = selectedSubjects.toSet().toList(); })
        )),
        ...selectedSubjects.where((s) => !subjectOptions.contains(s)).map((customSub) => InputChip(
          label: Text(customSub),
          selected: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          selectedColor: const Color(0xFFA2E8DD).withOpacity(0.4),
          onDeleted: () => setState(() => selectedSubjects.remove(customSub)),
        )),
      ]
    ),
    const SizedBox(height: 35),
    Row(children: [Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: () { setState(() { isEditing = false; _selectedImage = null; _triggerAnimation = !_triggerAnimation; }); _customSubjectController.clear(); fetchStudentData(); }, child: const Text("Cancel"))), const SizedBox(width: 12), Expanded(child: ElevatedButton(onPressed: updateStudentProfile, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E4C7A), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text("Save Changes")))]),
    const SizedBox(height: 30),
  ]);

  Widget _dropDown(String label, IconData icon, String? value, List<String> items, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(value: value, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: const Color(0xFF1E4C7A)), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged);

  Widget _field(TextEditingController c, String lbl, IconData i, {TextInputType type = TextInputType.text, int maxLines = 1}) => TextField(
    controller: c, keyboardType: type, maxLines: maxLines, 
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    decoration: InputDecoration(
      labelText: lbl, prefixIcon: Icon(i, color: const Color(0xFF1E4C7A)), filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E4C7A), width: 1.5)),
    )
  );
  Widget _gap() => const SizedBox(height: 15);
}