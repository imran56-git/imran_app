import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../animations/animation_constants.dart';
import '../animations/screen_pull_controller.dart';
import '../routes/app_routes.dart';
import '../utils/image_utils.dart';
import '../widgets/success_toast.dart';
import 'notification_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  final String currentUserId;

  const StudentProfileScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
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
      _college = TextEditingController(),
      _customSubjectController = TextEditingController();

  late AnimationController _menuAnimController;
  StreamSubscription<QuerySnapshot>? _notifSubscription;
  bool _isMenuExpanded = false;
  bool hasUnreadNotifications = false;

  Map<String, dynamic>? studentData;
  File? _selectedImage;
  bool isLoading = true, isEditing = false, _triggerAnimation = true;
  String? gender, studentClass;
  List<String> selectedSubjects = [];

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _accentTeal = Color(0xFF0D9488);
  static const Color _scaffoldBg = Color(0xFFF8FAFC);

  final classOptions = const [
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
    'Others'
  ];

  final subjectOptions = const [
    "Mathematics",
    "Physics",
    "Chemistry",
    "Biology",
    "English",
    "Computer Science",
    "History",
    "Geography"
  ];

  bool get isOwnProfile =>
      widget.currentUserId.isEmpty ||
      widget.currentUserId == (_auth.currentUser?.uid ?? "");

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    fetchStudentData();
    checkUnreadNotifications();

    _menuAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    _menuAnimController.dispose();
    for (var c in [
      _name,
      _phone,
      _location,
      _bio,
      _institution,
      _school,
      _college,
      _customSubjectController
    ]) {
      c.dispose();
    }
    super.dispose();
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

  Future<void> fetchStudentData() async {
    final targetUid = widget.currentUserId.isNotEmpty
        ? widget.currentUserId
        : (_auth.currentUser?.uid ?? "");
    if (targetUid.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      return;
    }
    try {
      final docSnap =
          await _firestore.collection('students').doc(targetUid).get();
      final data = docSnap.data() ?? {};
      if (!mounted) return;
      setState(() {
        studentData = data;
        _name.text = (data['name'] ?? data['fullName'] ?? '').toString();
        _phone.text = (data['phone'] ?? '').toString();
        _location.text = (data['location'] ?? '').toString();
        _bio.text = (data['bio'] ?? '').toString();
        _institution.text = (data['institution'] ?? '').toString();
        _school.text = (data['schoolName'] ?? '').toString();
        _college.text = (data['collegeName'] ?? '').toString();
        gender = data['gender']?.toString();
        studentClass = data['studentClass']?.toString();
        selectedSubjects = List<String>.from(data['interestedSubjects'] ?? []);
        isLoading = false;
        _triggerAnimation = !_triggerAnimation;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      _snack('Failed to load profile: $e', isError: true);
    }
  }

  Future<void> _pickProfileImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null && mounted) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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

  Future<void> _handleDeleteAccount() async {
    _showAnimatedPopup(
      title: 'Delete Account',
      message: 'This will permanently delete your account.\n\nAre you sure?',
      confirmText: 'Delete',
      isDelete: true,
      onConfirm: () async {
        try {
          final user = _auth.currentUser;
          if (user == null) return;
          final uid = user.uid;
          setState(() => isLoading = true);

          await _firestore.collection('students').doc(uid).delete();
          await _firestore
              .collection('usernames')
              .doc(uid)
              .delete()
              .catchError((_) {});
          await _storage
              .ref('students/$uid/profile.jpg')
              .delete()
              .catchError((_) {});

          await _clearLocalSession();
          await user.delete();

          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          }
        } catch (e) {
          if (mounted) setState(() => isLoading = false);
          if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
            _snack(
                'Security Error: Please logout and sign back in to delete your account.',
                isError: true);
          } else {
            _snack('Delete Failed: $e', isError: true);
          }
        }
      },
    );
  }

  Future<void> _handleSignOut() async {
    _showAnimatedPopup(
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmText: 'Sign Out',
      onConfirm: () async {
        setState(() => isLoading = true);
        await _auth.signOut();
        await _clearLocalSession();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }
      },
    );
  }

  Future<void> updateStudentProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    setState(() => isLoading = true);
    try {
      String? imageUrl = studentData?['profileImageUrl'];
      if (_selectedImage != null) {
        final File? compressed =
            await ImageHelper.compressImage(_selectedImage!);
        final ref = _storage.ref('students/$uid/profile.jpg');
        await ref.putFile(compressed ?? _selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }
      await _firestore.collection('students').doc(uid).set({
        'name': _name.text.trim(),
        'fullName': _name.text.trim(),
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

      if (mounted) {
        setState(() {
          isEditing = false;
          _selectedImage = null;
        });
      }
      await fetchStudentData();
      _snack('Profile updated successfully', isError: false);
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      _snack('Update failed: $e', isError: true);
    }
  }

  void _showServiceUnavailableDialog() {
    _showAnimatedPopup(
      title: 'Service Unavailable',
      message:
          'This service is currently disabled.\n\nIt will be available in a future update.\nThank you for your patience.',
      confirmText: 'OK',
      onConfirm: () async {},
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor:
              isError ? const Color(0xFFDC2626) : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  ImageProvider? get _profileImage {
    if (_selectedImage != null) return FileImage(_selectedImage!);
    final url = studentData?['profileImageUrl'];
    return (url != null && url.toString().trim().isNotEmpty)
        ? NetworkImage(url.toString())
        : null;
  }

  void _openMenu() {
    if (_isMenuExpanded) return;
    setState(() => _isMenuExpanded = true);
    _menuAnimController.forward();
  }

  void _closeMenu() {
    if (!_isMenuExpanded) return;
    _menuAnimController.reverse().then((_) {
      if (mounted) {
        setState(() => _isMenuExpanded = false);
      }
    });
  }

  void _openNotifications(Offset tapPos) {
    if (_isMenuExpanded) _closeMenu();
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
  }

  Widget _buildStaggeredMenuItem({
    required int index,
    required int totalItems,
    required Widget child,
  }) {
    final double start = (index * 0.12).clamp(0.0, 0.8);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final Animation<double> itemAnimation = CurvedAnimation(
      parent: _menuAnimController,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        backgroundColor: _primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: !isOwnProfile,
        titleSpacing: 20,
        title: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) {
            if (_isMenuExpanded) _closeMenu();
          },
          child: Row(
            children: [
              Text(
                isOwnProfile
                    ? (isEditing ? 'Edit Profile' : 'My Profile')
                    : 'Student Profile',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                ),
                child: const Text(
                  'STUDENT',
                  style: TextStyle(
                    color: Color(0xFF99F6E4),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildActionHeaderBar(),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (_) {
          if (_isMenuExpanded) _closeMenu();
        },
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: _brandBlue,
                  strokeWidth: 3.5,
                ),
              )
            : NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (_isMenuExpanded &&
                      notification is ScrollStartNotification) {
                    _closeMenu();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey(_triggerAnimation),
                      color: _scaffoldBg,
                      child: Column(
                        children: [
                          _buildHeader(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                            child: isEditing
                                ? _buildEditForm()
                                : _buildProfileDetails(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNotificationBellIcon() {
    return GestureDetector(
      onTapDown: (details) => _openNotifications(details.globalPosition),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          if (hasUnreadNotifications)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 8.5,
                height: 8.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(color: _primaryNavy, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionHeaderBar() {
    if (!isOwnProfile) {
      return _buildNotificationBellIcon();
    }

    final List<Widget> menuItems = [
      _buildNotificationBellIcon(),
      _buildGlassIconButton(
        icon: Icons.edit_rounded,
        tooltip: 'Edit Profile',
        onTap: () {
          _closeMenu();
          setState(() {
            isEditing = true;
            _triggerAnimation = !_triggerAnimation;
          });
        },
      ),
      _buildGlassIconButton(
        icon: Icons.payment_rounded,
        tooltip: 'Payment Ticket',
        onTap: () {
          _closeMenu();
          _showServiceUnavailableDialog();
        },
      ),
      _buildGlassIconButton(
        icon: Icons.logout_rounded,
        iconColor: Colors.orangeAccent,
        tooltip: 'Sign Out',
        onTap: () {
          _closeMenu();
          _handleSignOut();
        },
      ),
      _buildGlassIconButton(
        icon: Icons.delete_forever_rounded,
        iconColor: Colors.redAccent,
        tooltip: 'Delete Account',
        onTap: () {
          _closeMenu();
          _handleDeleteAccount();
        },
      ),
    ];

    if (_isMenuExpanded) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.32)),
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
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNotificationBellIcon(),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          tooltip: 'Menu',
          onPressed: _openMenu,
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 9),
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildHeader() {
    final currentUid = widget.currentUserId.isNotEmpty
        ? widget.currentUserId
        : (_auth.currentUser?.uid ?? 'N/A');
    final String initial =
        _name.text.trim().isNotEmpty ? _name.text.trim()[0].toUpperCase() : 'S';

    return FadeInDown(
      duration: const Duration(milliseconds: 380),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              _primaryNavy,
              Color(0xFF1E3A8A),
              _brandBlue,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(34),
            bottomRight: Radius.circular(34),
          ),
          boxShadow: [
            BoxShadow(
              color: _primaryNavy.withOpacity(0.16),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2DD4BF), Color(0xFF38BDF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      color: _primaryNavy,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF1E293B),
                      backgroundImage: _profileImage,
                      child: _profileImage == null
                          ? Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF5EEAD4),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                if (isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _pickProfileImage,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_accentTeal, _accentBlue],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _name.text.isEmpty ? "No Name Added" : _name.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _bio.text.isEmpty ? "No academic bio added yet" : _bio.text,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 13.2,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "REGISTRATION ID / UID",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          currentUid,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Clipboard.setData(ClipboardData(text: currentUid));
                      _snack("ID Copied to Clipboard!");
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.copy_all_rounded,
                        color: Color(0xFF5EEAD4),
                        size: 18,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: _primaryNavy.withOpacity(0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: _primaryNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildProfileDetails() => FadeInUp(
        duration: const Duration(milliseconds: 360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildQuickStatCard(
                  icon: Icons.school_rounded,
                  label: "Class / Grade",
                  value: (studentClass == null || studentClass!.isEmpty)
                      ? "Not Added"
                      : studentClass!,
                  accentColor: _accentBlue,
                ),
                const SizedBox(width: 12),
                _buildQuickStatCard(
                  icon: Icons.location_on_rounded,
                  label: "Home Area",
                  value: _location.text.isEmpty ? "Not Added" : _location.text,
                  accentColor: _accentTeal,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Row(
              children: [
                Icon(Icons.auto_stories_rounded,
                    size: 18, color: _brandBlue),
                SizedBox(width: 7),
                Text(
                  "Interested Subjects",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _primaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            selectedSubjects.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      "No Subjects Selected",
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
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
                              border:
                                  Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bookmark_rounded,
                                    size: 14, color: _accentBlue),
                                const SizedBox(width: 5),
                                Text(
                                  s,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF1E3A8A),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
            const SizedBox(height: 22),
            const Row(
              children: [
                Icon(Icons.badge_rounded, size: 18, color: _brandBlue),
                SizedBox(width: 7),
                Text(
                  "Student Information",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _primaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: _primaryNavy.withOpacity(0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _info(
                    Icons.person_rounded,
                    "Name",
                    _name.text,
                    const Color(0xFF2563EB),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _info(
                    Icons.wc_rounded,
                    "Gender",
                    isOwnProfile
                        ? (gender ?? "Not Added")
                        : "Hidden for Privacy",
                    const Color(0xFFF59E0B),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _info(
                    Icons.phone_android_rounded,
                    "Phone",
                    isOwnProfile ? _phone.text : "Hidden for Privacy",
                    const Color(0xFF7C3AED),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _info(
                    Icons.school_rounded,
                    "Class/Grade",
                    studentClass ?? "Not Added",
                    const Color(0xFF10B981),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _info(
                    Icons.history_edu_rounded,
                    "School Name",
                    _school.text,
                    const Color(0xFF0284C7),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _info(
                    Icons.account_balance_rounded,
                    "College Name",
                    _college.text,
                    const Color(0xFF4F46E5),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _info(
                    Icons.business_rounded,
                    "Tuition Institution",
                    _institution.text,
                    const Color(0xFF0D9488),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _info(
                    Icons.map_rounded,
                    "Home Location",
                    _location.text,
                    const Color(0xFFEF4444),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );

  Widget _info(
          IconData icon, String title, String value, Color accentColor) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.isEmpty ? "Not Added" : value,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: _primaryNavy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildEditForm() => Container(
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
                Icon(Icons.edit_note_rounded, color: _brandBlue, size: 22),
                SizedBox(width: 8),
                Text(
                  "Update Academic Profile",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                    color: _primaryNavy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _field(_name, "Full Name", Icons.person_rounded),
            _gap(),
            _field(_phone, "Phone Number", Icons.phone_rounded,
                type: TextInputType.phone),
            _gap(),
            _field(_location, "Home Location", Icons.location_on_rounded),
            _gap(),
            _dropDown(
              "Select Gender",
              Icons.people_rounded,
              gender,
              ['Male', 'Female'],
              (v) => setState(() => gender = v),
            ),
            _gap(),
            _dropDown(
              "Select Class",
              Icons.school_rounded,
              studentClass,
              classOptions,
              (v) => setState(() => studentClass = v),
            ),
            _gap(),
            _field(_school, "School Name", Icons.school_outlined),
            _gap(),
            _field(_college, "College Name", Icons.account_balance_rounded),
            _gap(),
            _field(
                _institution, "Tuition Institution", Icons.business_rounded),
            _gap(),
            _field(_bio, "Write Biography", Icons.info_outline_rounded,
                maxLines: 3),
            const SizedBox(height: 22),
            const Text(
              "Interested Subjects",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: _primaryNavy,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customSubjectController,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _primaryNavy,
                    ),
                    decoration: InputDecoration(
                      hintText: "Enter Custom Subject (e.g., Bengali)",
                      hintStyle: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: _accentBlue, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: _brandBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    onPressed: () {
                      final txt = _customSubjectController.text.trim();
                      if (txt.isNotEmpty) {
                        if (!selectedSubjects.contains(txt)) {
                          setState(() {
                            selectedSubjects.add(txt);
                          });
                        }
                        _customSubjectController.clear();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...subjectOptions.map(
                  (subject) {
                    final bool isSel = selectedSubjects.contains(subject);
                    return FilterChip(
                      label: Text(
                        subject,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: isSel ? _brandBlue : const Color(0xFF475569),
                        ),
                      ),
                      selected: isSel,
                      backgroundColor: const Color(0xFFF8FAFC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSel
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      selectedColor: const Color(0xFFEFF6FF),
                      checkmarkColor: _brandBlue,
                      onSelected: (v) => setState(() {
                        v
                            ? selectedSubjects.add(subject)
                            : selectedSubjects.remove(subject);
                        selectedSubjects = selectedSubjects.toSet().toList();
                      }),
                    );
                  },
                ),
                ...selectedSubjects
                    .where((s) => !subjectOptions.contains(s))
                    .map(
                      (customSub) => InputChip(
                        label: Text(
                          customSub,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        selected: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFF99F6E4)),
                        ),
                        selectedColor: const Color(0xFFF0FDF4),
                        deleteIconColor: const Color(0xFF0F766E),
                        onDeleted: () =>
                            setState(() => selectedSubjects.remove(customSub)),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      setState(() {
                        isEditing = false;
                        _selectedImage = null;
                        _triggerAnimation = !_triggerAnimation;
                      });
                      _customSubjectController.clear();
                      fetchStudentData();
                    },
                    child: const Text(
                      "Cancel",
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
                    onPressed: updateStudentProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      "Save Changes",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _dropDown(
    String label,
    IconData icon,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) =>
      DropdownButtonFormField<String>(
        value: items.contains(value) ? value : null,
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _accentBlue, width: 1.5),
          ),
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      );

  Widget _field(
    TextEditingController c,
    String lbl,
    IconData i, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) =>
      TextField(
        controller: c,
        keyboardType: type,
        maxLines: maxLines,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: _primaryNavy,
        ),
        decoration: InputDecoration(
          labelText: lbl,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
          prefixIcon: Icon(i, color: _brandBlue, size: 20),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _accentBlue, width: 1.5),
          ),
        ),
      );

  Widget _gap() => const SizedBox(height: 14);
}
