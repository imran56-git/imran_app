import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_utils.dart';
import '../utils/chat_colors.dart';
import '../widgets/success_toast.dart';
import 'location_picker_screen.dart';
import 'tuition_management_screen.dart';
import 'live/join_live_screen.dart';

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

  // গ্লোয়িং অ্যানিমেশনের জন্য কন্ট্রোলার
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

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

    // চমকানো (Glowing Effect) অ্যানিমেশন সেটআপ
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _classController.dispose();
    _bioController.dispose();
    _subjectSearchController.dispose();
    super.dispose();
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
        SuccessToast.show(context, 'Updated Successfully');
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
    required Future<void> Function() onConfirm,
    bool isDelete = false,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, a1, a2) => const SizedBox(),
      transitionBuilder: (dialogContext, anim, a2, child) {
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
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDelete ? Colors.red : Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await onConfirm();
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
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
      backgroundColor: const Color(0xFFF7F9FC),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.blue[800],
            elevation: 0,
            centerTitle: true,
            title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
            leading: widget.teacherId != null ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ) : null,
            actions: [if (widget.teacherId == null) _buildMenu(), const SizedBox(width: 8)],
            flexibleSpace: FlexibleSpaceBar(
              background: AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return ClipPath(
                    clipper: HeaderCurveClipper(),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[900]!, Colors.blue[700]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // ব্যাকগ্রাউন্ডের গ্লোয়িং কণা ইফেক্ট (যা প্রতি সেকেন্ডে রেসপনসিভ উপায়ে চমকাবে)
                          Positioned(
                            top: 40,
                            left: 30,
                            child: Icon(Icons.blur_on_rounded, color: Colors.white.withOpacity(_glowAnimation.value * 0.25), size: 60),
                          ),
                          Positioned(
                            bottom: 80,
                            right: 40,
                            child: Icon(Icons.blur_on_rounded, color: Colors.white.withOpacity(_glowAnimation.value * 0.2), size: 80),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -65),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    if (widget.teacherId == null && !isEditing) _buildDashboardSection(),
                    if (widget.teacherId == null && !isEditing) _buildToolsAndPayment(),
                    if (isEditing) _buildSaveCancelButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (val) {
        if (val == 'edit') {
          setState(() => isEditing = true);
        } else if (val == 'signout') {
          _showAnimatedPopup(
            title: 'Sign Out', 
            message: 'Are you sure you want to sign out?', 
            confirmText: 'Confirm', 
            onConfirm: () async {
              try {
                await _auth.signOut();
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (e) {
                debugPrint("Sign out failed: $e");
              }
            }
          );
        } else if (val == 'delete') {
          _showAnimatedPopup(
            title: 'Delete Account', 
            message: 'This will permanently delete your account.\nAre you sure?', 
            confirmText: 'Delete', 
            isDelete: true, 
            onConfirm: () async {
              try {
                await _firestore.collection('teachers').doc(targetUID).delete();
                await _auth.currentUser?.delete();
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (e) {
                debugPrint("Delete account failed: $e");
              }
            }
          );
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
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 6)),
            ],
          ),
          child: CircleAvatar(radius: 56, backgroundColor: Colors.blue[50], backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : (url != null ? NetworkImage(url) : null) as ImageProvider?),
        ),
        if (isEditing) Positioned(bottom: 0, right: 0, child: CircleAvatar(backgroundColor: Colors.blue[800], radius: 18, child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16))),
      ]),
    );
  }

  Widget _buildNameWithBadge() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_nameController.text.isEmpty ? "No Name" : _nameController.text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B1B1B))),
      if (teacherData?['isVerified'] ?? false) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, color: Colors.blue, size: 20)),
    ]);
  }

  Widget _buildFollowStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('follows').where('teacherId', isEqualTo: targetUID).snapshots(),
      builder: (context, snap) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
        child: Text('Followers: ${snap.data?.docs.length ?? 0}', style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 13)),
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
      _buildMaterial3Card("Bio", _bioController.text, Icons.description_outlined, const Color(0xFF3B82F6)),
      _buildMaterial3Card("Phone Number", _phoneController.text, Icons.phone_outlined, Colors.deepPurple),
      _buildMaterial3Card("Teaching Class", _classController.text, Icons.school_outlined, const Color(0xFF10B981)),
      _buildMaterial3Card("Gender", gender ?? "Not set", Icons.wc_outlined, const Color(0xFFF59E0B)),
      const SizedBox(height: 18),
      const Text("Teaching Areas (Locations)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B1B1B))),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: teacherLocations.map((l) => Chip(label: Text((l is Map) ? (l['address'] ?? "Unknown") : l.toString()), avatar: const Icon(Icons.location_on, size: 14, color: Colors.red), backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: Colors.grey.shade200))).toList()),
      const SizedBox(height: 18),
      const Text("Subjects", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B1B1B))),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: selectedSubjects.map((s) => Chip(label: Text(s), backgroundColor: Colors.blue[50], side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))).toList()),
    ]);
  }

  Widget _buildMaterial3Card(String title, String value, IconData icon, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: accentColor, size: 22),
        ),
        title: Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text(value.isEmpty ? "Not set" : value, style: const TextStyle(fontSize: 15, color: Color(0xFF1B1B1B), fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // --- ফায়ারস্টোর রিয়েল-টাইম ড্যাশবোর্ড সেকশন ---
  Widget _buildDashboardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text("Teacher Dashboard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B1B1B))),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            // ১. রিয়েল-টাইম টোটাল স্টুডেন্টস কাউন্টার
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('teachers').doc(targetUID).collection('students').snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return _buildDashboardCard("Total Students", "$count", Icons.people_alt_outlined, Colors.purple);
              },
            ),
            // ২. টুডেস ক্লাস কাউন্টার
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('live_classes').where('teacherId', isEqualTo: targetUID).snapshots(),
              builder: (context, snapshot) {
                int classCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return _buildDashboardCard("Today's Classes", "$classCount", Icons.calendar_today_outlined, Colors.orange);
              },
            ),
            // ৩. রিয়েল-টাইম পেন্ডিং পেমেন্ট ক্যালকুলেশন
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('payment_reminders').where('teacherId', isEqualTo: targetUID).where('status', isEqualTo: 'pending').snapshots(),
              builder: (context, snapshot) {
                double totalPending = 0;
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    totalPending += (double.tryParse(data['amount'].toString()) ?? 0);
                  }
                }
                return _buildDashboardCard("Pending Payments", "₹${totalPending.toStringAsFixed(0)}", Icons.account_balance_wallet_outlined, Colors.red);
              },
            ),
            // ৪. লাইভ ক্লাস অ্যাক্টিভ স্ট্যাটাস ট্র্যাকার
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('live_classes').where('teacherId', isEqualTo: targetUID).where('isLive', isEqualTo: true).snapshots(),
              builder: (context, snapshot) {
                bool isLiveActive = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                return _buildDashboardCard("Live Classes", isLiveActive ? "Active" : "Inactive", Icons.sensors_outlined, isLiveActive ? Colors.green : Colors.grey);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 18),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B1B1B))),
                const SizedBox(height: 2),
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    final query = _subjectSearchController.text.trim();
    final list = _subjects.where((s) => s.toLowerCase().contains(query.toLowerCase())).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _editField("Full Name", _nameController, Icons.person),
      _editField("Mobile Number", _phoneController, Icons.phone, keyboardType: TextInputType.phone),
      _editField("Bio", _bioController, Icons.info, maxLines: 3),
      _editField("Teaching Class", _classController, Icons.book),
      const Text("Gender", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 6),
      Row(children: [
        Radio<String>(value: 'Male', groupValue: gender, activeColor: Colors.blue[800], onChanged: (val) => setState(() => gender = val)),
        const Text('Male', style: TextStyle(fontSize: 15)),
        const SizedBox(width: 15),
        Radio<String>(value: 'Female', groupValue: gender, activeColor: Colors.blue[800], onChanged: (val) => setState(() => gender = val)),
        const Text('Female', style: TextStyle(fontSize: 15)),
      ]),
      const SizedBox(height: 15),
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
      const SizedBox(height: 16),
      Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFF1F5F9))), child: ListTile(leading: const Icon(Icons.videocam_rounded, color: Colors.red), title: const Text("Go Live", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), trailing: const Icon(Icons.chevron_right_rounded), onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => JoinLiveScreen(currentUserId: _auth.currentUser?.uid ?? '', currentUserName: _nameController.text.isEmpty ? 'Teacher' : _nameController.text, isTeacher: true)));
      })),
      const SizedBox(height: 4),
      Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFF1F5F9))), child: ListTile(leading: const Icon(Icons.assignment_turned_in_rounded, color: Colors.teal), title: const Text("Tuition Management", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), trailing: const Icon(Icons.chevron_right_rounded), onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => TuitionManagementScreen(currentUserId: _auth.currentUser?.uid ?? '', currentUserName: _nameController.text.isEmpty ? 'Teacher' : _nameController.text)));
      })),
      const SizedBox(height: 4),
      Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFF1F5F9))), child: ListTile(leading: const Icon(Icons.receipt_long_rounded, color: Colors.indigo, size: 22), title: const Text("Payment Confirmations", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), trailing: const Icon(Icons.chevron_right_rounded), onTap: _showPaymentDisabledPopup)),
    ]);
  }

  Widget _editField(String l, TextEditingController c, IconData i, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) => Padding(padding: const EdgeInsets.only(bottom: 15), child: TextField(controller: c, maxLines: maxLines, keyboardType: keyboardType, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))))));
}

// স্ক্রিনশটের মতো নিখুঁত বাঁকানো অবতল শেপ তৈরি করার কাস্টম ক্লিপার (ফিক্সড মেথড)
class HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 45);
    Offset controlPoint = Offset(size.width / 2, size.height + 15);
    Offset endPoint = Offset(size.width, size.height - 45);
    // endPoint.endY পরিবর্তন করে ফ্লাটার স্ট্যান্ডার্ড endPoint.dy করা হয়েছে
    path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, endPoint.dx, endPoint.dy);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

const List<String> _subjects = [
  'Bengali', 'English', 'Mathematics', 'General Science', 'Social Studies', 'ICT (Information & Tech)', 'Class1-8 all subjects', 'Physics', 'Chemistry', 'Biology', 'Higher Mathematics', 'Accounting', 'Business Studies', 'Finance & Banking', 'Geography & Environment', 'History', 'Civics & Citizenship', 'Economics', 'Physics 1st/2nd Paper', 'Chemistry 1st/2nd Paper', 'Biology 1st/2nd Paper', 'Higher Math 1st/2nd Paper', 'Statistics', 'Management', 'Marketing', 'Computer Science', 'App Development (Flutter)', 'Graphic Design', 'Cyber Security', 'Robotics', 'Data Science', 'UI/UX Design', 'Fine Arts', 'Music', 'Photography', 'Agriculture', 'IELTS/GRE Preparation'
];