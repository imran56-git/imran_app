import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  late TabController _tabController;
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

  static const Color primaryTeal = Color(0xFF0F766E);
  static const Color primaryBlue = Color(0xFF1E4C7A);
  static const Color scaffoldBg = Color(0xFFF8FAFC);

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
      padding: const EdgeInsets.only(top: 8),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
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
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          "Teacher Connections",
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          _isSearching
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          color: const Color(0xFF334155),
                          size: 23,
                        ),
                        tooltip: _isSearching ? 'Close Search' : 'Search',
                        onPressed: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) {
                              _searchController.clear();
                              _searchQuery = '';
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: _isSearching
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 4),
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                onChanged: (val) => setState(() =>
                                    _searchQuery = val.trim().toLowerCase()),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Search teachers by name...',
                                  hintStyle: TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: Color(0xFF64748B),
                                    size: 19,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 10),
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
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: primaryTeal,
                indicatorWeight: 3,
                labelColor: primaryTeal,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Following"),
                        if (_followingRequests.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_followingRequests.length}',
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
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
                        const Text("My Teachers"),
                        if (_myTeachers.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_myTeachers.length}',
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
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
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _FollowingTabView(
                    isLoading: _isFollowingLoading,
                    errorMessage: _followingError,
                    requests: filteredFollowing,
                    onRefresh: () async => _listenToConnections(),
                    onCancel: _cancelFollowRequest,
                    onTapProfile: _openProfile,
                    skeletonBuilder: _buildSkeletonLoader,
                  ),
                  _MyTeachersTabView(
                    isLoading: _isTeachersLoading,
                    errorMessage: _teachersError,
                    teachers: filteredTeachers,
                    onRefresh: () async => _listenToConnections(),
                    onTapProfile: _openProfile,
                    onMoreTap: _showActionMenu,
                    skeletonBuilder: _buildSkeletonLoader,
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
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_add_alt_1_outlined,
                                    size: 68,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    "No pending requests",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    "Teachers you requested to follow will appear here.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13.5,
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
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
                          margin: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
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
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E4C7A),
                                              fontSize: 17,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: const BoxDecoration(
                                                color: Colors.orange,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                (teacher.subtitle != null &&
                                                        teacher.subtitle!
                                                            .isNotEmpty)
                                                    ? teacher.subtitle!
                                                    : "Request pending approval",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
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
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                  ),
                                  onPressed: () => onCancel(teacher),
                                  child: const Text(
                                    "Cancel",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
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
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.school_outlined,
                                    size: 68,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    "No teachers yet",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    "Connect with teachers to see them here.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13.5,
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: teachers.length,
                      itemBuilder: (context, index) {
                        final teacher = teachers[index];
                        return ConnectedUserTile(
                          user: teacher,
                          onTap: () => onTapProfile(teacher),
                          onMoreTap: () => onMoreTap(teacher),
                        );
                      },
                    ),
    );
  }
}
