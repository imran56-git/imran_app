import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../utils/image_utils.dart';
import '../utils/chat_colors.dart';
import '../widgets/success_toast.dart';
import 'location_picker_screen.dart';
import 'tuition_management_screen.dart';
import 'live/join_live_screen.dart';
import 'notification_screen.dart';

class TeacherProfileScreen extends StatefulWidget {
  final String currentUserId;

  const TeacherProfileScreen({
    super.key, 
    required this.currentUserId,
  });

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  Map<String, dynamic>? teacherData;
  bool isLoading = true, isEditing = false;
  String requestStatus = 'none'; // none, pending, accepted
  File? _selectedImage;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _subjectSearchController = TextEditingController();

  String? gender;
  List<String> selectedSubjects = [];
  List<dynamic> teacherLocations = [];
  bool hasUnreadNotifications = false;

  bool get isOwnProfile => widget.currentUserId == (_auth.currentUser?.uid ?? "");

  @override
  void initState() {
    super.initState();
    fetchTeacherData();
    checkFollowRequestStatus();
    checkUnreadNotifications();

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
    if (widget.currentUserId.isEmpty) return;
    try {
      final doc = await _firestore.collection('teachers').doc(widget.currentUserId).get();
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

  void checkFollowRequestStatus() async {
    final currentUID = _auth.currentUser?.uid;
    if (currentUID == null || isOwnProfile) return;

    final doc = await _firestore.collection('follow_requests').doc('${currentUID}_${widget.currentUserId}').get();
    if (mounted) {
      if (doc.exists) {
        setState(() => requestStatus = doc.data()?['status'] ?? 'pending');
      } else {
        setState(() => requestStatus = 'none');
      }
    }
  }

  void checkUnreadNotifications() async {
    final currentUID = _auth.currentUser?.uid;
    if (currentUID == null) return;

    _firestore.collection('notifications')
      .where('receiverId', isEqualTo: currentUID)
      .where('isRead', isEqualTo: false)
      .snapshots().listen((snap) {
        if (mounted) {
          setState(() => hasUnreadNotifications = snap.docs.isNotEmpty);
        }
      });
  }

  void triggerFollowAction() async {
    final currentUID = _auth.currentUser?.uid;
    if (currentUID == null || isOwnProfile) return;

    final requestDocRef = _firestore.collection('follow_requests').doc('${currentUID}_${widget.currentUserId}');

    if (requestStatus == 'none') {
      final studentDoc = await _firestore.collection('students').doc(currentUID).get();
      final studentData = studentDoc.data() ?? {};

      await requestDocRef.set({
        'teacherId': widget.currentUserId,
        'studentId': currentUID,
        'studentName': studentData['name'] ?? 'A Student',
        'studentPhotoUrl': studentData['photoUrl'] ?? '',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('notifications').add({
        'receiverId': widget.currentUserId,
        'senderId': currentUID,
        'senderName': studentData['name'] ?? 'A Student',
        'senderPhotoUrl': studentData['photoUrl'] ?? '',
        'message': 'wants to follow you.',
        'type': 'follow_request',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      SuccessToast.show(context, 'Follow request sent!');
    } else {
      await requestDocRef.delete();
      SuccessToast.show(context, 'Unfollowed / Request removed');
    }
    checkFollowRequestStatus();
  }

  Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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
                      backgroundColor: isDelete ? Colors.red : const Color(0xFF1565C0),
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
    double headerHeight = 170.0;
    double profileRadius = 56.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, child) {
                            return ClipPath(
                              clipper: HeaderCurveClipper(),
                              child: Container(
                                height: headerHeight,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue[900]!, Colors.blue[700]!],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 50,
                                      left: 24,
                                      child: Icon(Icons.blur_on_rounded, color: Colors.white.withOpacity(_glowAnimation.value * 0.28), size: 55),
                                    ),
                                    Positioned(
                                      top: 45,
                                      right: 24,
                                      child: Icon(Icons.blur_on_rounded, color: Colors.white.withOpacity(_glowAnimation.value * 0.24), size: 55),
                                    ),
                                    Positioned(
                                      top: 40,
                                      left: 0,
                                      right: 0,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                          const Text(
                                            'Profile Details',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 19),
                                          ),
                                          _buildMenu(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          top: headerHeight - profileRadius - 10,
                          child: _buildProfileImage(profileRadius),
                        ),
                      ],
                    ),
                    SizedBox(height: profileRadius + 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _buildNameWithBadge(),
                          const SizedBox(height: 8),

                          _buildUidIdentityCard(),
                          const SizedBox(height: 10),

                          if (!isEditing) _buildFollowStats(),
                          if (!isOwnProfile) _buildFollowButton(),
                          const SizedBox(height: 20),
                          isEditing ? _buildEditForm() : _buildViewProfile(),
                          if (isOwnProfile && !isEditing) _buildDashboardSection(),
                          if (isOwnProfile && !isEditing) _buildToolsAndPayment(),
                          if (isEditing) _buildSaveCancelButtons(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUidIdentityCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("TEACHER UID", style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(
                  widget.currentUserId,
                  style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.currentUserId));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Teacher UID Copied!"),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },            
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.copy_all_rounded, color: Colors.blue.shade800, size: 18),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMenu() {
    return Stack(
      children: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          onSelected: (val) {
            if (val == 'edit') {
              setState(() => isEditing = true);
            } else if (val == 'notifications') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
            } else if (val == 'share') {
              Clipboard.setData(ClipboardData(text: "Check out this teacher profile on FYBTT. UID: ${widget.currentUserId}"));
              SuccessToast.show(context, 'Profile link copied!');
            } else if (val == 'report') {
              SuccessToast.show(context, 'User Reported Successfully');
            } else if (val == 'block') {
              SuccessToast.show(context, 'User Blocked Successfully');
            } else if (val == 'signout') {
              _showAnimatedPopup(
                title: 'Sign Out', 
                message: 'Are you sure you want to sign out?', 
                confirmText: 'Confirm', 
                onConfirm: () async {
                  await _auth.signOut();
                  await _clearLocalSession(); 
                  if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
                }
              );
            }
          },
          itemBuilder: (ctx) => isOwnProfile 
            ? [
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 20), SizedBox(width: 10), Text('Edit Profile')])),
                const PopupMenuItem(value: 'notifications', child: Row(children: [Icon(Icons.notifications_none_rounded, s