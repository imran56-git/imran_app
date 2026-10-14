import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/connected_user_model.dart';
import '../services/chat_service.dart';
import '../services/follow_service.dart';
import '../widgets/connected_user_tile.dart';
import '../widgets/connection_action_bottom_sheet.dart';
import 'chat_screen.dart';

class StudentTeachersScreen extends StatefulWidget {
  const StudentTeachersScreen({Key? key}) : super(key: key);

  @override
  State<StudentTeachersScreen> createState() => _StudentTeachersScreenState();
}

class _StudentTeachersScreenState extends State<StudentTeachersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FollowService _followService = FollowService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription? _requestsSubscription;

  bool _isFollowingLoading = true;
  bool _isTeachersLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  String? _followingError;
  String? _teachersError;

  List<ConnectedUserModel> _followingRequests = [];
  List<ConnectedUserModel> _myTeachers = [];

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentTeal = Color(0xFF0F766E);
  static const Color _scaffoldBg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenToConnections();
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToConnections() {
    final String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      if (mounted) {
        setState(() {
          _isFollowingLoading = false;
          _isTeachersLoading = false;
          _followingError = "User not logged in";
          _teachersError = "User not logged in";
        });
      }
      return;
    }

    _requestsSubscription?.cancel();
    _requestsSubscription = _firestore
        .collection('follow_requests')
        .where('studentId', isEqualTo: currentUserId)
        .snapshots()
        .listen(
      (snapshot) {
        _processSnapshotData(snapshot, currentUserId);
      },
      onError: (error) {
        debugPrint("Error listening to follow_requests: $error");
        if (mounted) {
          setState(() {
            _isFollowingLoading = false;
            _isTeachersLoading = false;
            _followingError = "Failed to load requests";
            _teachersError = "Failed to load teachers";
          });
        }
      },
    );
  }

  Future<void> _processSnapshotData(
      QuerySnapshot snapshot, String currentUserId) async {
    final Set<String> pendingTeacherIds = {};
    final Set<String> acceptedTeacherIds = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final status = data['status']?.toString().toLowerCase();
      final teacherId = data['teacherId']?.toString();

      if (teacherId != null && teacherId.isNotEmpty) {
        if (status == 'pending') {
          pendingTeacherIds.add(teacherId);
        } else if (status == 'accepted') {
          acceptedTeacherIds.add(teacherId);
        }
      }
    }

    final loadedPending = await _loadTeacherProfiles(pendingTeacherIds);
    final loadedAccepted = await _loadTeacherProfiles(acceptedTeacherIds);

    if (mounted) {
      setState(() {
        _followingRequests = loadedPending;
        _myTeachers = loadedAccepted;
        _isFollowingLoading = false;
        _isTeachersLoading = false;
        _followingError = null;
        _teachersError = null;
      });
    }
  }

  Future<List<ConnectedUserModel>> _loadTeacherProfiles(
      Set<String> teacherIds) async {
    if (teacherIds.isEmpty) return [];

    final List<ConnectedUserModel> results = [];

    await Future.wait(
      teacherIds.map((tId) async {
        try {
          DocumentSnapshot tDoc =
              await _firestore.collection('teachers').doc(tId).get();
          if (!tDoc.exists) {
            tDoc = await _firestore.collection('users').doc(tId).get();
          }

          if (tDoc.exists && tDoc.data() != null) {
            final model = ConnectedUserModel.fromFirestore(
              tDoc.data() as Map<String, dynamic>,
              tId,
              'teacher',
            );
            results.add(model);
          }
        } catch (e) {
          debugPrint("Error loading profile for teacher $tId: $e");
        }
      }),
    );

    results.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return results;
  }

  Future<void> _cancelFollowRequest(ConnectedUserModel teacher) async {
    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      await _followService.cancelRequest(teacher.uid, currentUserId);

      if (mounted) {
        setState(() {
          _followingRequests.removeWhere((t) => t.uid == teacher.uid);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Cancelled follow request to ${teacher.name}"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _primaryNavy,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Action failed. Please try again.")),
        );
      }
    }
  }

  Future<void> _unfollowTeacher(ConnectedUserModel teacher) async {
    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      await _followService.unfollowTeacher(teacher.uid, currentUserId);

      if (mounted) {
        setState(() {
          _myTeachers.removeWhere((t) => t.uid == teacher.uid);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unfollowed ${teacher.name}"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _primaryNavy,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Unable to unfollow. Please try again.")),
        );
      }
    }
  }

  void _openMessage(ConnectedUserModel teacher) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) return;

    final String chatRoomId =
        _chatService.getChatRoomId(currentUserId, teacher.uid);

    final String profileImage =
        (teacher.photoUrl != null && teacher.photoUrl!.isNotEmpty)
            ? teacher.photoUrl!
            : (teacher.profileImageUrl ?? '');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatRoomId: chatRoomId,
          receiverId: teacher.uid,
          receiverName: teacher.name,
          receiverProfilePic: profileImage,
          currentUserId: currentUserId,
          isTeacher: false,
        ),
      ),
    );
  }

  void _openProfile(ConnectedUserModel teacher) {
    Navigator.pushNamed(
      context,
      '/teacher_profile',
      arguments: {'teacherId': teacher.uid},
    );
  }

  void _showActionMenu(ConnectedUserModel teacher) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ConnectionActionBottomSheet(
        user: teacher,
        onMessage: () => _openMessage(teacher),
        onUnfollowConfirm: () => _unfollowTeacher(teacher),
      ),
    );
  }

  List<ConnectedUserModel> _filterList(List<ConnectedUserModel> source) {
    if (_searchQuery.isEmpty) return source;
    return source.where((t) {
      final name = t.name.toLowerCase();
      final sub = (t.subtitle ?? '').toLowerCase();
      return name.contains(_searchQuery) || sub.contains(_searchQuery);
    }).toList();
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFollowing = _filterList(_followingRequests);
    final filteredTeachers = _filterList(_myTeachers);

    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Teacher Connections",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _primaryNavy,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Manage your follow requests & verified educators",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) {
                              _searchController.clear();
                              _searchQuery = '';
                            }
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Icon(
                            _isSearching
                                ? Icons.close_rounded
                                : Icons.search_rounded,
                            color: _primaryNavy,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: _isSearching
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 4),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                onChanged: (val) => setState(() =>
                                    _searchQuery = val.trim().toLowerCase()),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _primaryNavy,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Search teachers by name...',
                                  hintStyle: TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: Color(0xFF64748B),
                                    size: 19,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 11),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Container(
                height: 46,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _accentTeal.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add_rounded, size: 16),
                          const SizedBox(width: 7),
                          const Text("Following"),
                          if (_followingRequests.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6.5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_followingRequests.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.school_rounded, size: 17),
                          const SizedBox(width: 7),
                          const Text("My Teachers"),
                          if (_myTeachers.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6.5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_myTeachers.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  RepaintBoundary(
                    child: _FollowingTabView(
                      isLoading: _isFollowingLoading,
                      errorMessage: _followingError,
                      requests: filteredFollowing,
                      onRefresh: () async => _listenToConnections(),
                      onCancel: _cancelFollowRequest,
                      onTapProfile: _openProfile,
                      skeletonBuilder: _buildSkeletonLoader,
                    ),
                  ),
                  RepaintBoundary(
                    child: _MyTeachersTabView(
                      isLoading: _isTeachersLoading,
                      errorMessage: _teachersError,
                      teachers: filteredTeachers,
                      onRefresh: () async => _listenToConnections(),
                      onTapProfile: _openProfile,
                      onMoreTap: _showActionMenu,
                      skeletonBuilder: _buildSkeletonLoader,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowingTabView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<ConnectedUserModel> requests;
  final Future<void> Function() onRefresh;
  final Function(ConnectedUserModel) onCancel;
  final Function(ConnectedUserModel) onTapProfile;
  final Widget Function() skeletonBuilder;

  const _FollowingTabView({
    Key? key,
    required this.isLoading,
    required this.errorMessage,
    required this.requests,
    required this.onRefresh,
    required this.onCancel,
    required this.onTapProfile,
    required this.skeletonBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF0F766E),
      onRefresh: onRefresh,
      child: isLoading
          ? skeletonBuilder()
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage!,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: onRefresh,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Retry",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : requests.isEmpty
                  ? Center(
                      child: ListView(
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 28),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_add_alt_1_outlined,
                                    size: 64,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    "No pending requests",
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    "Teachers you requested to follow will appear here.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final teacher = requests[index];
                        final hasPhoto = (teacher.photoUrl != null &&
                                teacher.photoUrl!.isNotEmpty) ||
                            (teacher.profileImageUrl != null &&
                                teacher.profileImageUrl!.isNotEmpty);
                        final String displayPhoto = (teacher.photoUrl != null &&
                                teacher.photoUrl!.isNotEmpty)
                            ? teacher.photoUrl!
                            : (teacher.profileImageUrl ?? '');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withOpacity(0.035),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(26),
                                  onTap: () => onTapProfile(teacher),
                                  child: CircleAvatar(
                                    radius: 25,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    backgroundImage: hasPhoto
                                        ? NetworkImage(displayPhoto)
                                        : null,
                                    child: !hasPhoto
                                        ? Text(
                                            teacher.name.isNotEmpty
                                                ? teacher.name[0].toUpperCase()
                                                : 'T',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E4C7A),
                                              fontSize: 17,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => onTapProfile(teacher),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          teacher.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              width: 7.5,
                                              height: 7.5,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFF59E0B),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                (teacher.subtitle != null &&
                                                        teacher.subtitle!
                                                            .isNotEmpty)
                                                    ? teacher.subtitle!
                                                    : "Request pending approval",
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                    side: const BorderSide(
                                        color: Color(0xFFFCA5A5)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 7),
                                  ),
                                  onPressed: () => onCancel(teacher),
                                  child: const Text(
                                    "Cancel",
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
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
}

class _MyTeachersTabView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<ConnectedUserModel> teachers;
  final Future<void> Function() onRefresh;
  final Function(ConnectedUserModel) onTapProfile;
  final Function(ConnectedUserModel) onMoreTap;
  final Widget Function() skeletonBuilder;

  const _MyTeachersTabView({
    Key? key,
    required this.isLoading,
    required this.errorMessage,
    required this.teachers,
    required this.onRefresh,
    required this.onTapProfile,
    required this.onMoreTap,
    required this.skeletonBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF0F766E),
      onRefresh: onRefresh,
      child: isLoading
          ? skeletonBuilder()
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        errorMessage!,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: onRefresh,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Retry",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : teachers.isEmpty
                  ? Center(
                      child: ListView(
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 28),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.school_outlined,
                                    size: 64,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    "No teachers yet",
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    "Connect with teachers to see them here.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: teachers.length,
                      itemBuilder: (context, index) {
                        final teacher = teachers[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ConnectedUserTile(
                            user: teacher,
                            onTap: () => onTapProfile(teacher),
                            onMoreTap: () => onMoreTap(teacher),
                          ),
                        );
                      },
                    ),
    );
  }
}
