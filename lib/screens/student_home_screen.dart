import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ai_assistant_screen.dart';
import 'chat_list_screen.dart';
import 'notification_screen.dart';
import 'search_teacher_screen.dart';
import 'student_profile_screen.dart';
import 'student_teachers_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  final String currentUserId;

  const StudentHomeScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;
  late final Stream<QuerySnapshot> _unreadNotificationsStream;

  bool _isOffline = false;
  Timer? _connectivityTimer;

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _scaffoldBg = Color(0xFFF8FAFC);

  static const List<String> _tabSubtitles = [
    'Chats & Study Groups',
    'Connected Educators',
    'Discover Verified Tutors',
    'AI Study Companion',
    'Academic Profile',
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      RepaintBoundary(
        key: const PageStorageKey<String>('student_tab_chats'),
        child: ChatListScreen(
          currentUserId: widget.currentUserId,
          isTeacher: false,
        ),
      ),
      const RepaintBoundary(
        key: PageStorageKey<String>('student_tab_teachers'),
        child: StudentTeachersScreen(),
      ),
      const RepaintBoundary(
        key: PageStorageKey<String>('student_tab_search'),
        child: TeacherSearchScreen(),
      ),
      const RepaintBoundary(
        key: PageStorageKey<String>('student_tab_ai'),
        child: AiAssistantScreen(),
      ),
      RepaintBoundary(
        key: const PageStorageKey<String>('student_tab_profile'),
        child: StudentProfileScreen(currentUserId: widget.currentUserId),
      ),
    ];

    _unreadNotificationsStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: widget.currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots();

    _startConnectivityMonitoring();
  }

  void _startConnectivityMonitoring() {
    _checkConnectivity();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 2));
      final bool hasNet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted && _isOffline == hasNet) {
        setState(() => _isOffline = !hasNet);
      }
    } catch (_) {
      if (mounted && !_isOffline) {
        setState(() => _isOffline = true);
      }
    }
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  void _handleFabPressed() {
    HapticFeedback.lightImpact();
    if (_selectedIndex == 0) {
      setState(() => _selectedIndex = 2);
    } else if (_selectedIndex == 2) {
      _showFilterBottomSheet();
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.exit_to_app_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Exit FYBTT?",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: _primaryNavy,
              ),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to close the application?",
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryNavy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              "Exit",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: _accentBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter Teachers',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: _primaryNavy,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Use the search & subject chips on the screen to refine tutors',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: _brandBlue,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Advanced filters are active directly inside the Search tab (by Subject, Class, Location & Rating).',
                          style: TextStyle(
                            color: Color(0xFF334155),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationActionButton() {
    return StreamBuilder<QuerySnapshot>(
      stream: _unreadNotificationsStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final int unreadCount = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final type = (data['type'] ?? '').toString().toLowerCase();
          return type != 'chat' &&
              type != 'message' &&
              type != 'group_message' &&
              !data.containsKey('chatRoomId');
        }).length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: _primaryNavy,
                    size: 22,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4.5, vertical: 1),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      _buildNotificationActionButton(),
      const SizedBox(width: 12),
    ];
  }

  Widget _buildModernBottomNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF1E4C7A), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _accentBlue.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: 21,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.8,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? _brandBlue : const Color(0xFF64748B),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineStatusBar() {
    if (!_isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: const Color(0xFFEF4444),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text(
            'You are offline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showFab = _selectedIndex == 0 || _selectedIndex == 2;
    final bool showAppBar = _selectedIndex == 1 || _selectedIndex == 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return;
        }

        final shouldExit = await _showExitConfirmationDialog();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              _selectedIndex == 0 ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: _scaffoldBg,
          appBar: showAppBar
              ? AppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 0.5,
                  centerTitle: false,
                  titleSpacing: 16,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(
                      height: 1,
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          gradient: const LinearGradient(
                            colors: [_brandBlue, _accentBlue],
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            color: Colors.white,
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.school_rounded,
                                  color: _brandBlue,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'FYBTT',
                                  style: TextStyle(
                                    color: _primaryNavy,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18.5,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _accentBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'STUDENT',
                                    style: TextStyle(
                                      color: _accentBlue,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _tabSubtitles[_selectedIndex],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11.2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: _buildAppBarActions(),
                )
              : null,
          body: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          floatingActionButton: showFab
              ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [_brandBlue, _accentBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _brandBlue.withOpacity(0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    highlightElevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    onPressed: _handleFabPressed,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        _selectedIndex == 0
                            ? Icons.person_search_rounded
                            : Icons.tune_rounded,
                        key: ValueKey<int>(_selectedIndex),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                )
              : null,
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOfflineStatusBar(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryNavy.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      children: [
                        _buildModernBottomNavItem(
                          index: 0,
                          icon: Icons.chat_bubble_outline_rounded,
                          activeIcon: Icons.chat_bubble_rounded,
                          label: 'Messages',
                        ),
                        _buildModernBottomNavItem(
                          index: 1,
                          icon: Icons.school_outlined,
                          activeIcon: Icons.school_rounded,
                          label: 'Teachers',
                        ),
                        _buildModernBottomNavItem(
                          index: 2,
                          icon: Icons.search_rounded,
                          activeIcon: Icons.manage_search_rounded,
                          label: 'Search',
                        ),
                        _buildModernBottomNavItem(
                          index: 3,
                          icon: Icons.auto_awesome_outlined,
                          activeIcon: Icons.auto_awesome_rounded,
                          label: 'AI Assistant',
                        ),
                        _buildModernBottomNavItem(
                          index: 4,
                          icon: Icons.person_outline_rounded,
                          activeIcon: Icons.person_rounded,
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
