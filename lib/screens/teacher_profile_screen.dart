import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../animations/animation_constants.dart';
import '../animations/screen_pull_controller.dart';
import '../models/rating_model.dart';
import '../routes/app_routes.dart';
import '../services/follow_service.dart';
import '../utils/image_utils.dart';
import '../widgets/follow_button.dart';
import '../widgets/success_toast.dart';
import 'diary_history_screen.dart';
import 'live/join_live_screen.dart';
import 'location_picker_screen.dart';
import 'notification_screen.dart';
import 'teacher_follow_requests_screen.dart';
import 'teacher_reviews_screen.dart';
import 'tuition_management_screen.dart';

class TeacherProfileScreen extends StatefulWidget {
  final String currentUserId;

  const TeacherProfileScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final FollowService _followService = FollowService();

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _menuMenuAnimController;

  // Cached streams to prevent unnecessary reloading on tab switch or scroll
  Stream<QuerySnapshot>? _pendingRequestsStream;
  Stream<int>? _followersCountStream;
  Stream<QuerySnapshot>? _acceptedStudentsStream;
  Stream<QuerySnapshot>? _todayClassesStream;
  Stream<QuerySnapshot>? _studentFeesStream;
  Stream<QuerySnapshot>? _activeLiveClassesStream;

  StreamSubscription<QuerySnapshot>? _notifSubscription;
  bool _isMenuExpanded = false;

  Map<String, dynamic>? teacherData;
  bool isLoading = true;
  bool isEditing = false;
  bool _isUploadingBanner = false;

  File? _selectedImage;
  File? _selectedBannerImage;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _subjectSearchController =
      TextEditingController();
  final TextEditingController _instituteController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();

  String? gender;
  List<String> selectedSubjects = [];
  List<dynamic> teacherLocations = [];
  bool hasUnreadNotifications = false;

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _scaffoldBg = Color(0xFFF8FAFC);

  bool get isOwnProfile =>
      widget.currentUserId == (_auth.currentUser?.uid ?? "");

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initCachedStreams();
    fetchTeacherData();
    checkUnreadNotifications();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _menuMenuAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
  }

  void _initCachedStreams() {
    if (widget.currentUserId.isEmpty) return;

    _pendingRequestsStream = _firestore
        .collection('follow_requests')
        .where('teacherId', isEqualTo: widget.currentUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots();

    _followersCountStream =
        _followService.streamFollowersCount(widget.currentUserId);

    _acceptedStudentsStream = _firestore
        .collection('follow_requests')
        .where('teacherId', isEqualTo: widget.currentUserId)
        .where('status', isEqualTo: 'accepted')
        .snapshots();

    _todayClassesStream = _firestore
        .collection('live_classes')
        .where('teacherId', isEqualTo: widget.currentUserId)
        .snapshots();

    _studentFeesStream = _firestore
        .collection('student_fees')
        .where('teacherId', isEqualTo: widget.currentUserId)
        .snapshots();

    _activeLiveClassesStream = _firestore
        .collection('live_classes')
        .where('teacherId', isEqualTo: widget.currentUserId)
        .where('isLive', isEqualTo: true)
        .snapshots();
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    _glowController.dispose();
    _menuMenuAnimController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _classController.dispose();
    _bioController.dispose();
    _subjectSearchController.dispose();
    _instituteController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> fetchTeacherData() async {
    if (widget.currentUserId.isEmpty) return;
    try {
      final doc = await _firestore
          .collection('teachers')
          .doc(widget.currentUserId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data();
        final String expVal = (data?['experience'] ??
                data?['teachingExperience'] ??
                data?['experienceYears'] ??
                '')
            .toString();

        setState(() {
          teacherData = data;
          _nameController.text = (data?['name'] ?? data?['fullName'] ?? '').toString();
          _phoneController.text = (data?['phone'] ?? '').toString();
          _classController.text = (data?['class'] ?? '').toString();
          _bioController.text = (data?['bio'] ?? '').toString();
          _instituteController.text = (data?['institute'] ?? '').toString();
          _experienceController.text = expVal;
          gender = data?['gender']?.toString();
          selectedSubjects = List<String>.from(data?['subjects'] ?? []);
          teacherLocations = List.from(data?['locations'] ?? []);
          isLoading = false;
        });
      } else if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void checkUnreadNotifications() {
    final currentUID = _auth.currentUser?.uid;
    if (currentUID == null) return;

    _notifSubscription?.cancel();
    _notifSubscription = _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: currentUID)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final bool hasNonChatUnread = snap.docs.any((doc) {
        final data = doc.data();
        final String type = (data['type'] ?? '').toString().toLowerCase();
        if (type == 'chat' || type == 'group_message') return false;
        final bool isRead = data['isRead'] == true || data['status'] == 'read';
        return !isRead;
      });
      setState(() => hasUnreadNotifications = hasNonChatUnread);
    });
  }

  Future<void> _pickAndUploadBanner() async {
    if (!isOwnProfile) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      final file = File(picked.path);
      setState(() {
        _selectedBannerImage = file;
      });

      // If user is not in full edit mode, upload immediately for instant UX
      if (!isEditing) {
        final uid = _auth.currentUser?.uid;
        if (uid == null) return;
        setState(() => _isUploadingBanner = true);
        File? compressed = await ImageHelper.compressImage(file);
        final ref = _storage.ref().child('teachers/$uid/banner.jpg');
        await ref.putFile(compressed ?? file);
        final bannerUrl = await ref.getDownloadURL();
        await _firestore.collection('teachers').doc(uid).update({
          'bannerImageUrl': bannerUrl,
          'coverImageUrl': bannerUrl,
        });
        if (mounted) {
          setState(() {
            teacherData ??= {};
            teacherData!['bannerImageUrl'] = bannerUrl;
            teacherData!['coverImageUrl'] = bannerUrl;
            _isUploadingBanner = false;
          });
          SuccessToast.show(context, 'Profile banner updated!');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingBanner = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update banner: $e')),
        );
      }
    }
  }

  Future<void> _clearLocalSessionAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        String uid = user.uid;
        await _firestore.collection('teachers').doc(uid).delete();
        await user.delete();
        await _clearLocalSessionAndNavigate();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Account deletion failed: ${e.toString()} (Re-authentication required)"),
          ),
        );
      }
    }
  }

  void _openMapPicker() async {
    final List<Map<String, dynamic>>? results = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
    );

    if (results != null && results.isNotEmpty) {
      setState(() {
        teacherLocations.addAll(results);
      });

      if (!isEditing) {
        final uid = _auth.currentUser?.uid;
        if (uid != null) {
          try {
            await _firestore.collection('teachers').doc(uid).update({
              'locations': teacherLocations,
            });
            if (mounted) {
              SuccessToast.show(context, 'Teaching areas synchronized!');
            }
          } catch (_) {}
        }
      }
    }
  }

  Future<void> updateTeacherProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    setState(() => isLoading = true);
    try {
      String? imageUrl = teacherData?['profileImageUrl'];
      String? bannerUrl =
          (teacherData?['bannerImageUrl'] ?? teacherData?['coverImageUrl'])
              ?.toString();

      if (_selectedImage != null) {
        File? compressedFile =
            await ImageHelper.compressImage(_selectedImage!);
        final ref = _storage.ref().child('teachers/$uid/profile.jpg');
        await ref.putFile(compressedFile ?? _selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      if (_selectedBannerImage != null) {
        File? compressedBanner =
            await ImageHelper.compressImage(_selectedBannerImage!);
        final bannerRef = _storage.ref().child('teachers/$uid/banner.jpg');
        await bannerRef.putFile(compressedBanner ?? _selectedBannerImage!);
        bannerUrl = await bannerRef.getDownloadURL();
      }

      final String expText = _experienceController.text.trim();

      await _firestore.collection('teachers').doc(uid).update({
        'name': _nameController.text.trim(),
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'class': _classController.text.trim(),
        'bio': _bioController.text.trim(),
        'institute': _instituteController.text.trim(),
        'experience': expText,
        'teachingExperience': expText,
        'gender': gender,
        'profileImageUrl': imageUrl,
        if (bannerUrl != null && bannerUrl.isNotEmpty) ...{
          'bannerImageUrl': bannerUrl,
          'coverImageUrl': bannerUrl,
        },
        'subjects': selectedSubjects,
        'locations': teacherLocations,
      });

      if (mounted) {
        SuccessToast.show(context, 'Updated Successfully');
        setState(() {
          isEditing = false;
          _selectedImage = null;
          _selectedBannerImage = null;
        });
        fetchTeacherData();
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Route _createGenieRoute(Widget page, Offset tapPosition) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final screenSize = MediaQuery.of(context).size;
        final double alignX = (tapPosition.dx / screenSize.width) * 2 - 1;
        final double alignY = (tapPosition.dy / screenSize.height) * 2 - 1;
        final Alignment alignment = Alignment(alignX, alignY);

        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return Align(
          alignment: alignment,
          child: ScaleTransition(
            scale: curve,
            alignment: alignment,
            child: FadeTransition(
              opacity: curve,
              child: child,
            ),
          ),
        );
      },
    );
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
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(
              opacity: anim,
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                title: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        color: _primaryNavy)),
                content: Text(message,
                    style: const TextStyle(
                        fontSize: 14.5, color: Color(0xFF475569))),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDelete ? const Color(0xFFDC2626) : _brandBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await onConfirm();
                    },
                    child: Text(confirmText,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14.5)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showExitAnimatedPopup() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, a1, a2) => const SizedBox(),
      transitionBuilder: (dialogContext, anim, a2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(
              opacity: anim,
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                title: const Text("Exit App",
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        color: _primaryNavy)),
                content: const Text("Are you sure you want to exit?",
                    style:
                        TextStyle(fontSize: 14.5, color: Color(0xFF475569))),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      SystemNavigator.pop();
                    },
                    child: const Text('Exit',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14.5)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openMenu() {
    if (_isMenuExpanded) return;
    setState(() => _isMenuExpanded = true);
    _menuMenuAnimController.forward();
  }

  void _closeMenu() {
    if (!_isMenuExpanded) return;
    _menuMenuAnimController.reverse().then((_) {
      if (mounted) {
        setState(() => _isMenuExpanded = false);
      }
    });
  }

  Widget _buildStaggeredMenuItem({
    required int index,
    required int totalItems,
    required Widget child,
  }) {
    final double start = (index * 0.12).clamp(0.0, 0.8);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final Animation<double> itemAnimation = CurvedAnimation(
      parent: _menuMenuAnimController,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );

    return ScaleTransition(
      scale: itemAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.3, 0.0),
          end: Offset.zero,
        ).animate(itemAnimation),
        child: child,
      ),
    );
  }

  void _showPendingDuesSheet(
      double totalDue, List<Map<String, dynamic>> dueStudents) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.red,
                          size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pending Tuition Fees',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Student breakdown of unpaid dues',
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade600, Colors.red.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Outstanding',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${totalDue.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${dueStudents.length} Students',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Students with Due (${dueStudents.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: dueStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 56, color: Colors.green.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'All Dues Cleared!',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No pending payments from any enrolled student.',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: dueStudents.length,
                      itemBuilder: (context, index) {
                        final student = dueStudents[index];
                        final String name = student['studentName'] ?? 'Student';
                        final String uid = student['studentId'] ?? '';
                        final String subject = student['subject'] ?? '';
                        final double amount =
                            (student['due'] as double?) ?? 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.red.shade50,
                                child: Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5,
                                          color: Color(0xFF0F172A)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subject.isNotEmpty
                                          ? '$subject  •  $uid'
                                          : uid,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontFamily: 'monospace'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${amount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFFDC2626)),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'DUE',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.red.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 1,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DiaryHistoryScreen(
                        currentUserId: widget.currentUserId,
                        currentUserName: _nameController.text.isEmpty
                            ? 'Teacher'
                            : _nameController.text,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.history_edu_rounded, size: 20),
                label: const Text(
                  'MANAGE IN DIARY HISTORY',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _resolveBannerImageProvider() {
    if (_selectedBannerImage != null) {
      return FileImage(_selectedBannerImage!);
    }
    final String? bannerUrl =
        (teacherData?['bannerImageUrl'] ?? teacherData?['coverImageUrl'])
            ?.toString();
    if (bannerUrl != null && bannerUrl.trim().isNotEmpty) {
      return NetworkImage(bannerUrl.trim());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double topInset = MediaQuery.of(context).padding.top;
    // Standard 16:9 / 2.5:1 wide banner height for mobile
    final double bannerHeight = 205.0 + topInset;
    const double profileRadius = 56.0;
    final bool canPopScreen = Navigator.canPop(context) && !isOwnProfile;
    final ImageProvider? bannerProvider = _resolveBannerImageProvider();

    return PopScope(
      canPop: canPopScreen && !_isMenuExpanded,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isMenuExpanded) {
          _closeMenu();
          return;
        }
        _showExitAnimatedPopup();
      },
      child: Scaffold(
        backgroundColor: _scaffoldBg,
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _brandBlue),
              )
            : GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (_isMenuExpanded) _closeMenu();
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (_isMenuExpanded &&
                        notification is ScrollStartNotification) {
                      _closeMenu();
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // Exclusive Teacher Banner + Overlapping Avatar Header
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: bannerHeight,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0F172A),
                                    Color(0xFF1E3A8A),
                                    Color(0xFF1E4C7A),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                image: bannerProvider != null
                                    ? DecorationImage(
                                        image: bannerProvider,
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(30),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryNavy.withOpacity(0.16),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Subtle decorative pattern when no custom banner is set
                                  if (bannerProvider == null)
                                    Positioned(
                                      right: -30,
                                      top: -20,
                                      child: Container(
                                        width: 170,
                                        height: 170,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.05),
                                        ),
                                      ),
                                    ),
                                  // Scrim gradient for readable top bar & bottom contrast
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(30),
                                      ),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.48),
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.42),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Top Title + Action Menu
                                  Positioned(
                                    top: topInset + 10,
                                    left: 14,
                                    right: 14,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (canPopScreen)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    right: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.28),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons
                                                        .arrow_back_ios_new_rounded,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                ),
                                              )
                                            else
                                              const SizedBox(width: 4),
                                            Text(
                                              isOwnProfile
                                                  ? (isEditing
                                                      ? 'Edit Profile'
                                                      : 'My Profile')
                                                  : 'Educator Profile',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                fontSize: 21,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Flexible(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: _buildActionHeaderBar(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Exclusive Teacher Banner Upload / Edit Button
                                  if (isOwnProfile)
                                    Positioned(
                                      right: 16,
                                      bottom: 14,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          onTap: _isUploadingBanner
                                              ? null
                                              : _pickAndUploadBanner,
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                  sigmaX: 10, sigmaY: 10),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 7,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.45),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.35),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (_isUploadingBanner)
                                                      const SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    else
                                                      const Icon(
                                                        Icons
                                                            .photo_camera_back_rounded,
                                                        color: Colors.white,
                                                        size: 15,
                                                      ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _isUploadingBanner
                                                          ? 'Uploading...'
                                                          : (bannerProvider !=
                                                                  null
                                                              ? 'Change Cover'
                                                              : 'Add Cover'),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: bannerHeight - profileRadius - 6,
                              child: _buildProfileImage(profileRadius),
                            ),
                          ],
                        ),
                        const SizedBox(height: profileRadius + 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              _buildNameWithBadge(),
                              const SizedBox(height: 10),
                              _buildUidIdentityCard(),
                              const SizedBox(height: 14),
                              _buildRatingSummaryCard(),
                              const SizedBox(height: 12),
                              if (!isEditing) _buildFollowStats(),
                              if (!isOwnProfile) const SizedBox(height: 12),
                              if (!isOwnProfile) _buildFollowButtonWidget(),
                              if (!isOwnProfile)
                                _buildStudentRatingActionButton(),
                              const SizedBox(height: 22),
                              isEditing
                                  ? _buildEditForm()
                                  : _buildViewProfile(),
                              if (isOwnProfile && !isEditing)
                                _buildDashboardSection(),
                              if (isOwnProfile && !isEditing)
                                _buildToolsAndPayment(),
                              if (isEditing) _buildSaveCancelButtons(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildActionHeaderBar() {
    if (!_isMenuExpanded) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.22)),
        ),
        child: IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(
            Icons.more_vert_rounded,
            color: Colors.white,
            size: 22,
          ),
          tooltip: 'Menu',
          onPressed: _openMenu,
        ),
      );
    }

    final List<Widget> menuItems = [];

    if (isOwnProfile) {
      menuItems.add(
        StreamBuilder<QuerySnapshot>(
          stream: _pendingRequestsStream,
          builder: (context, snapshot) {
            final int pendingCount =
                snapshot.hasData ? snapshot.data!.docs.length : 0;
            return GestureDetector(
              onTapDown: (details) {
                _closeMenu();
                Navigator.push(
                  context,
                  _createGenieRoute(
                    TeacherFollowRequestsScreen(
                        teacherId: widget.currentUserId),
                    details.globalPosition,
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    if (pendingCount > 0)
                      Positioned(
                        right: -4,
                        top: -3,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.orangeAccent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                              minWidth: 15, minHeight: 15),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    menuItems.add(
      GestureDetector(
        onTapDown: (details) {
          final Offset tapPos = details.globalPosition;
          _closeMenu();
          ScreenPullController.executeSafeNavigation(
            context: context,
            navigationAction: () async {
              Navigator.pushNamed(
                context,
                AppRoutes.notification,
                arguments: {
                  'useScreenPull': true,
                  'destination': const NotificationScreen(),
                  'currentScreen': widget,
                  'pullPoint': tapPos,
                },
              );
            },
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 20,
              ),
              if (hasUnreadNotifications)
                Positioned(
                  right: 0,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (isOwnProfile) {
      menuItems.addAll([
        _buildGlassIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit Profile',
          onTap: () {
            _closeMenu();
            setState(() => isEditing = true);
          },
        ),
        _buildGlassIconButton(
          icon: Icons.share_outlined,
          tooltip: 'Share Profile',
          onTap: () {
            _closeMenu();
            Clipboard.setData(
              ClipboardData(
                text:
                    "Check out this teacher profile on FYBTT. UID: ${widget.currentUserId}",
              ),
            );
            SuccessToast.show(context, 'Profile link copied!');
          },
        ),
        _buildGlassIconButton(
          icon: Icons.logout_rounded,
          iconColor: Colors.orangeAccent,
          tooltip: 'Sign Out',
          onTap: () {
            _closeMenu();
            _showAnimatedPopup(
              title: 'Sign Out',
              message: 'Are you sure you want to sign out?',
              confirmText: 'Confirm',
              onConfirm: () async {
                await _auth.signOut();
                await _clearLocalSessionAndNavigate();
              },
            );
          },
        ),
        _buildGlassIconButton(
          icon: Icons.delete_forever_rounded,
          iconColor: Colors.redAccent,
          tooltip: 'Delete Account',
          onTap: () {
            _closeMenu();
            _showAnimatedPopup(
              title: 'Delete Account',
              message:
                  'This will permanently delete your account. Are you sure?',
              confirmText: 'Delete',
              isDelete: true,
              onConfirm: () async {
                await _deleteAccount();
              },
            );
          },
        ),
      ]);
    } else {
      menuItems.add(
        _buildGlassIconButton(
          icon: Icons.share_outlined,
          tooltip: 'Share Profile',
          onTap: () {
            _closeMenu();
            Clipboard.setData(
              ClipboardData(
                text:
                    "Check out this teacher profile on FYBTT. UID: ${widget.currentUserId}",
              ),
            );
            SuccessToast.show(context, 'Profile link copied!');
          },
        ),
      );
    }

    return GestureDetector(
      onTap: () {},
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                menuItems.length,
                (index) => _buildStaggeredMenuItem(
                  index: index,
                  totalItems: menuItems.length,
                  child: menuItems[index],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    Color iconColor = Colors.white,
  }) {
    return IconButton(
      icon: Icon(icon, color: iconColor, size: 20),
      tooltip: tooltip,
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildRatingSummaryCard() {
    double avgRating =
        (teacherData?['averageRating'] as num?)?.toDouble() ?? 0.0;
    double allTimeRating =
        (teacherData?['allTimeRating'] as num?)?.toDouble() ?? 0.0;
    int reviewCount = (teacherData?['reviewCount'] as num?)?.toInt() ?? 0;
    String currentSeason =
        teacherData?['currentSeason'] ?? RatingModel.getCurrentSeason();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: _primaryNavy.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFD97706), size: 20),
                          const SizedBox(width: 4),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          "$currentSeason Rating",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  "All-Time: ★ ${allTimeRating.toStringAsFixed(1)} ($reviewCount Reviews)",
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF0FDF4),
              foregroundColor: const Color(0xFF0F766E),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF99F6E4)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherReviewsScreen(
                    teacherId: widget.currentUserId,
                    teacherName: _nameController.text.isEmpty
                        ? "Teacher"
                        : _nameController.text,
                    teacherProfileUrl: teacherData?['profileImageUrl'],
                    currentStudentId: _auth.currentUser?.uid ?? "",
                  ),
                ),
              );
            },
            icon: const Icon(Icons.rate_review_outlined, size: 16),
            label: const Text(
              "View Reviews",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRatingActionButton() {
    String currentUID = _auth.currentUser?.uid ?? "";
    if (currentUID.isEmpty) return const SizedBox();

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore
          .collection('ratings')
          .doc('${widget.currentUserId}_$currentUID')
          .get(),
      builder: (context, snapshot) {
        bool hasRated = snapshot.hasData && snapshot.data!.exists;

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  hasRated ? const Color(0xFFD97706) : const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(190, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: Icon(
                hasRated ? Icons.edit_note_rounded : Icons.star_rounded,
                size: 19),
            label: Text(
              hasRated ? "Edit Rating" : "Give Rating",
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherReviewsScreen(
                    teacherId: widget.currentUserId,
                    teacherName: _nameController.text.isEmpty
                        ? "Teacher"
                        : _nameController.text,
                    teacherProfileUrl: teacherData?['profileImageUrl'],
                    currentStudentId: currentUID,
                  ),
                ),
              ).then((_) => fetchTeacherData());
            },
          ),
        );
      },
    );
  }

  Widget _buildUidIdentityCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: _primaryNavy.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "TEACHER UID",
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.currentUserId,
                  style: const TextStyle(
                    color: _primaryNavy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Clipboard.setData(ClipboardData(text: widget.currentUserId));
              SuccessToast.show(context, "Teacher UID Copied!");
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Icon(
                Icons.copy_all_rounded,
                color: _accentBlue,
                size: 18,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProfileImage(double radius) {
    final url = teacherData?['profileImageUrl'];
    final String nameText =
        _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'T';

    return GestureDetector(
      onTap: isEditing
          ? () async {
              final picked = await _picker.pickImage(
                  source: ImageSource.gallery, imageQuality: 80);
              if (picked != null) {
                setState(() => _selectedImage = File(picked.path));
              }
            }
          : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: _primaryNavy.withOpacity(0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: radius,
              backgroundColor: const Color(0xFFE0F2FE),
              backgroundImage: _selectedImage != null
                  ? FileImage(_selectedImage!)
                  : (url != null && url.toString().isNotEmpty
                      ? NetworkImage(url.toString())
                      : null) as ImageProvider?,
              child: (_selectedImage == null &&
                      (url == null || url.toString().isEmpty))
                  ? Text(
                      nameText[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: _brandBlue,
                      ),
                    )
                  : null,
            ),
          ),
          if (isEditing)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_brandBlue, _accentBlue],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNameWithBadge() {
    final bool isVerified = teacherData?['isVerified'] == true ||
        teacherData?['status'] == 'approved';
    final bool hasGolden = teacherData?['hasGoldenBadge'] == true;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            _nameController.text.isEmpty ? "No Name" : _nameController.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: _primaryNavy,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (isVerified)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(Icons.verified_rounded,
                color: Color(0xFF0284C7), size: 22),
          ),
        if (hasGolden)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.workspace_premium_rounded,
                color: Color(0xFFF59E0B), size: 22),
          ),
      ],
    );
  }

  Widget _buildFollowStats() {
    return StreamBuilder<int>(
      stream: _followersCountStream,
      builder: (context, snapshot) {
        int count = snapshot.data ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_alt_rounded,
                  size: 15, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 6),
              Text(
                'Followers: $count',
                style: const TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFollowButtonWidget() {
    final currentUID = _auth.currentUser?.uid ?? "";
    if (currentUID.isEmpty) return const SizedBox();

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('students').doc(currentUID).get(),
      builder: (context, studentSnapshot) {
        if (studentSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        bool isStudent =
            studentSnapshot.hasData && studentSnapshot.data!.exists;

        if (isStudent) {
          final studentData =
              studentSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final studentName =
              studentData['name'] ?? studentData['fullName'] ?? 'Student';
          final studentPhoto = studentData['photoUrl'] ??
              studentData['profileImageUrl'] ??
              '';

          return FollowButton(
            teacherId: widget.currentUserId,
            studentId: currentUID,
            teacherName:
                _nameController.text.isEmpty ? 'Teacher' : _nameController.text,
            studentName: studentName,
            teacherPhoto: teacherData?['profileImageUrl'] ?? '',
            studentPhoto: studentPhoto,
          );
        } else {
          return FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('teachers').doc(currentUID).get(),
            builder: (context, teacherSnapshot) {
              final tData =
                  teacherSnapshot.data?.data() as Map<String, dynamic>? ?? {};
              final currentUserName = tData['name'] ?? 'User';
              final currentUserPhoto = tData['profileImageUrl'] ?? '';

              return FollowButton(
                teacherId: widget.currentUserId,
                studentId: currentUID,
                teacherName: _nameController.text.isEmpty
                    ? 'Teacher'
                    : _nameController.text,
                studentName: currentUserName,
                teacherPhoto: teacherData?['profileImageUrl'] ?? '',
                studentPhoto: currentUserPhoto,
              );
            },
          );
        }
      },
    );
  }

  Widget _buildViewProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMaterial3Card(
          "Tuition / Institute Name",
          _instituteController.text,
          Icons.domain_rounded,
          const Color(0xFF4F46E5),
        ),
        _buildMaterial3Card(
          "Teaching Experience",
          _experienceController.text,
          Icons.workspace_premium_rounded,
          const Color(0xFF0D9488),
        ),
        _buildMaterial3Card(
          "Bio",
          _bioController.text,
          Icons.description_rounded,
          const Color(0xFF2563EB),
        ),
        _buildMaterial3Card(
          "Phone Number",
          isOwnProfile ? _phoneController.text : "Hidden for Privacy",
          Icons.phone_rounded,
          const Color(0xFF7C3AED),
        ),
        _buildMaterial3Card(
          "Teaching Class",
          _classController.text,
          Icons.school_rounded,
          const Color(0xFF10B981),
        ),
        _buildMaterial3Card(
          "Gender",
          isOwnProfile ? (gender ?? "Not set") : "Hidden for Privacy",
          Icons.wc_rounded,
          const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 18),
        _buildSectionTitle(
            "Teaching Areas (Locations)", Icons.location_on_rounded),
        const SizedBox(height: 10),
        teacherLocations.isEmpty
            ? _buildEmptyChipNotice("No teaching locations added yet")
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: teacherLocations
                    .map(
                      (l) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 15, color: Color(0xFFEF4444)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                (l is Map)
                                    ? (l['address'] ?? "Unknown").toString()
                                    : l.toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryNavy,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
        const SizedBox(height: 20),
        _buildSectionTitle("Subjects", Icons.menu_book_rounded),
        const SizedBox(height: 10),
        selectedSubjects.isEmpty
            ? _buildEmptyChipNotice("No subjects listed yet")
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedSubjects
                    .map(
                      (s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _brandBlue),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: _primaryNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChipNotice(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMaterial3Card(
      String title, String value, IconData icon, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: _primaryNavy.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accentColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3.0),
          child: Text(
            value.isEmpty ? "Not set" : value,
            style: const TextStyle(
              fontSize: 15,
              color: _primaryNavy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 14),
          child: _buildSectionTitle(
              "Teacher Dashboard", Icons.dashboard_customize_rounded),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.38,
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: _acceptedStudentsStream,
              builder: (context, snapshot) {
                int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return _buildDashboardCard(
                  "Total Students",
                  "$count",
                  Icons.people_alt_rounded,
                  const Color(0xFF7C3AED),
                );
              },
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _todayClassesStream,
              builder: (context, snapshot) {
                int classCount =
                    snapshot.hasData ? snapshot.data!.docs.length : 0;
                return _buildDashboardCard(
                  "Today's Classes",
                  "$classCount",
                  Icons.calendar_today_rounded,
                  const Color(0xFFEA580C),
                );
              },
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _studentFeesStream,
              builder: (context, snapshot) {
                double totalPending = 0;
                List<Map<String, dynamic>> dueStudents = [];

                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final double due =
                        (data['totalDue'] as num?)?.toDouble() ?? 0.0;
                    if (due > 0) {
                      totalPending += due;
                      dueStudents.add({
                        'id': doc.id,
                        'studentId': data['studentId'] ?? '',
                        'studentName': data['studentName'] ?? 'Student',
                        'due': due,
                        'subject': data['subject'] ?? '',
                        'monthlyFee':
                            (data['monthlyFee'] as num?)?.toDouble() ?? 0.0,
                      });
                    }
                  }
                }

                dueStudents.sort((a, b) =>
                    (b['due'] as double).compareTo(a['due'] as double));

                return _buildDashboardCard(
                  "Pending Payments",
                  "₹${totalPending.toStringAsFixed(0)}",
                  Icons.account_balance_wallet_rounded,
                  const Color(0xFFDC2626),
                  onTap: () => _showPendingDuesSheet(totalPending, dueStudents),
                  actionWidget: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dueStudents.isNotEmpty
                              ? "${dueStudents.length}"
                              : "0",
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 13, color: Color(0xFFB91C1C)),
                      ],
                    ),
                  ),
                );
              },
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _activeLiveClassesStream,
              builder: (context, snapshot) {
                bool isLiveActive =
                    snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                return _buildDashboardCard(
                  "Live Classes",
                  isLiveActive ? "Active" : "Inactive",
                  Icons.sensors_rounded,
                  isLiveActive
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF64748B),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    Widget? actionWidget,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: _primaryNavy.withOpacity(0.035),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 19),
                  ),
                  if (actionWidget != null) actionWidget,
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: _primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    final query = _subjectSearchController.text.trim();
    final list = _subjects
        .where((s) => s.toLowerCase().contains(query.toLowerCase()))
        .toList();

    const List<String> quickExperienceOptions = [
      '1+ Year',
      '2+ Years',
      '3+ Years',
      '5+ Years',
      '8+ Years',
      '10+ Years',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: _primaryNavy.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.badge_rounded, color: _brandBlue, size: 20),
              SizedBox(width: 8),
              Text(
                "Personal & Academic Details",
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: _primaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _editField("Full Name", _nameController, Icons.person_rounded),
          _editField(
            "Mobile Number",
            _phoneController,
            Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          ),
          _editField(
            "Tuition / Institute Name",
            _instituteController,
            Icons.domain_rounded,
          ),
          // Added Teaching Experience field + quick preset chips
          _editField(
            "Teaching Experience (e.g. 5 Years)",
            _experienceController,
            Icons.workspace_premium_rounded,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickExperienceOptions.map((exp) {
                final bool isSelected =
                    _experienceController.text.trim().toLowerCase() ==
                        exp.toLowerCase();
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      _experienceController.text = exp;
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _brandBlue
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? _brandBlue
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      exp,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          _editField(
            "Bio",
            _bioController,
            Icons.info_outline_rounded,
            maxLines: 3,
          ),
          _editField(
            "Teaching Class (e.g. Class 11-12, BSc)",
            _classController,
            Icons.menu_book_rounded,
          ),
          const SizedBox(height: 4),
          const Text(
            "Gender",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: _primaryNavy,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: ['Male', 'Female'].map((g) {
              final bool isSel = gender == g;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: g == 'Male' ? 10 : 0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => gender = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSel
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSel
                              ? _accentBlue
                              : const Color(0xFFE2E8F0),
                          width: isSel ? 1.6 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            g == 'Male'
                                ? Icons.male_rounded
                                : Icons.female_rounded,
                            size: 19,
                            color: isSel
                                ? _accentBlue
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            g,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isSel
                                  ? _accentBlue
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Add Teaching Areas",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: _primaryNavy,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  backgroundColor: const Color(0xFFF0FDF4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _openMapPicker,
                icon: const Icon(Icons.map_outlined, size: 17),
                label: const Text(
                  "Pick Locations",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            ],
          ),
          if (teacherLocations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: teacherLocations
                  .map(
                    (loc) => Chip(
                      backgroundColor: const Color(0xFFF8FAFC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      label: Text(
                        (loc is Map)
                            ? (loc['address'] ?? "Unknown").toString()
                            : loc.toString(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onDeleted: () =>
                          setState(() => teacherLocations.remove(loc)),
                    ),
                  )
                  .toList(),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Select Subjects",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: _primaryNavy,
                ),
              ),
              Text(
                "${selectedSubjects.length} Selected",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _subjectSearchController,
            decoration: InputDecoration(
              hintText: "Search or add custom subject...",
              hintStyle: const TextStyle(
                  fontSize: 13.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              suffixIcon: (query.isNotEmpty && list.isEmpty)
                  ? IconButton(
                      icon: const Icon(Icons.add_circle_rounded,
                          color: Color(0xFF16A34A)),
                      onPressed: () {
                        if (!selectedSubjects.contains(query)) {
                          setState(() {
                            selectedSubjects.add(query);
                            _subjectSearchController.clear();
                          });
                        }
                      },
                    )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _accentBlue, width: 1.5),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: list
                  .map(
                    (s) => CheckboxListTile(
                      dense: true,
                      activeColor: _brandBlue,
                      title: Text(
                        s,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: _primaryNavy,
                        ),
                      ),
                      value: selectedSubjects.contains(s),
                      onChanged: (v) => setState(() => v!
                          ? selectedSubjects.add(s)
                          : selectedSubjects.remove(s)),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveCancelButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                setState(() {
                  isEditing = false;
                  _selectedImage = null;
                  _selectedBannerImage = null;
                });
              },
              child: const Text(
                "CANCEL",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: updateTeacherProfile,
              child: const Text(
                "SAVE CHANGES",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsAndPayment() {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildActionTile(
          icon: Icons.videocam_rounded,
          iconColor: const Color(0xFFDC2626),
          bgColor: const Color(0xFFFEE2E2),
          title: "Go Live",
          subtitle: "Start an interactive live class session",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => JoinLiveScreen(
                  currentUserId: _auth.currentUser?.uid ?? '',
                  currentUserName: _nameController.text.isEmpty
                      ? 'Teacher'
                      : _nameController.text,
                  isTeacher: true,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.assignment_turned_in_rounded,
          iconColor: const Color(0xFF0F766E),
          bgColor: const Color(0xFFCCFBF1),
          title: "Tuition Management",
          subtitle: "Track monthly fees, attendance & academic diary",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TuitionManagementScreen(
                  currentUserId: _auth.currentUser?.uid ?? '',
                  currentUserName: _nameController.text.isEmpty
                      ? 'Teacher'
                      : _nameController.text,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: _primaryNavy.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: _primaryNavy,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.chevron_right_rounded,
            color: _primaryNavy,
            size: 18,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: _primaryNavy,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            prefixIcon: Icon(icon, color: _brandBlue, size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _accentBlue, width: 1.5),
            ),
          ),
        ),
      );
}

class HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 35);
    Offset controlPoint = Offset(size.width / 2, size.height + 15);
    Offset endPoint = Offset(size.width, size.height - 35);
    path.quadraticBezierTo(
        controlPoint.dx, controlPoint.dy, endPoint.dx, endPoint.dy);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

const List<String> _subjects = [
  'Bengali',
  'English',
  'Mathematics',
  'General Science',
  'Social Studies',
  'ICT (Information & Tech)',
  'Class1-8 all subjects',
  'Physics',
  'Chemistry',
  'Biology',
  'Higher Mathematics',
  'Accounting',
  'Business Studies',
  'Finance & Banking',
  'Geography & Environment',
  'History',
  'Civics & Citizenship',
  'Economics',
  'Physics 1st/2nd Paper',
  'Chemistry 1st/2nd Paper',
  'Biology 1st/2nd Paper',
  'Higher Math 1st/2nd Paper',
  'Statistics',
  'Management',
  'Marketing',
  'Computer Science',
  'App Development (Flutter)',
  'Graphic Design',
  'Cyber Security',
  'Robotics',
  'Data Science',
  'UI/UX Design',
  'Fine Arts',
  'Music',
  'Photography',
];
