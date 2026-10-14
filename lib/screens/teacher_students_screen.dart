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

class TeacherStudentsScreen extends StatefulWidget {
  const TeacherStudentsScreen({Key? key}) : super(key: key);

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FollowService _followService = FollowService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription? _requestsSubscription;

  bool _isFollowersLoading = true;
  bool _isStudentsLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  String? _followersError;
  String? _studentsError;

  List<ConnectedUserModel> _followersRequests = [];
  List<ConnectedUserModel> _students = [];

  static const Color tealPrimary = Color(0xFF0F766E);
  static const Color tealDark = Color(0xFF115E59);
  static const Color scaffoldBg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenToNetwork();
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToNetwork() {
    final String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      if (mounted) {
        setState(() {
          _isFollowersLoading = false;
          _isStudentsLoading = false;
          _followersError = "User not logged in";
          _studentsError = "User not logged in";
        });
      }
      return;
    }

    _requestsSubscription?.cancel();
    _requestsSubscription = _firestore
        .collection('follow_requests')
        .where('teacherId', isEqualTo: currentUserId)
        .snapshots()
        .listen(
      (snapshot) {
        _processSnapshotData(snapshot, currentUserId);
      },
      onError: (error) {
        debugPrint("Error listening to follow_requests: $error");
        if (mounted) {
          setState(() {
            _isFollowersLoading = false;
            _isStudentsLoading = false;
            _followersError = "Failed to load requests";
            _studentsError = "Failed to load students";
          });
        }
      },
    );
  }

  Future<void> _processSnapshotData(
      QuerySnapshot snapshot, String currentUserId) async {
    final Set<String> pendingStudentIds = {};
    final Set<String> acceptedStudentIds = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final status = data['status']?.toString().toLowerCase();
      final studentId = data['studentId']?.toString();

      if (studentId != null && studentId.isNotEmpty) {
        if (status == 'pending') {
          pendingStudentIds.add(studentId);
        } else if (status == 'accepted') {
          acceptedStudentIds.add(studentId);
        }
      }
    }

    final loadedFollowers = await _loadStudentProfiles(pendingStudentIds);
    final loadedStudents = await _loadStudentProfiles(acceptedStudentIds);

    if (mounted) {
      setState(() {
        _followersRequests = loadedFollowers;
        _students = loadedStudents;
        _isFollowersLoading = false;
        _isStudentsLoading = false;
        _followersError = null;
        _studentsError = null;
      });
    }
  }

  Future<List<ConnectedUserModel>> _loadStudentProfiles(
      Set<String> studentIds) async {
    if (studentIds.isEmpty) return [];

    final List<ConnectedUserModel> results = [];

    await Future.wait(
      studentIds.map((sId) async {
        try {
          DocumentSnapshot sDoc =
              await _firestore.collection('students').doc(sId).get();
          if (!sDoc.exists) {
            sDoc = await _firestore.collection('users').doc(sId).get();
          }

          if (sDoc.exists && sDoc.data() != null) {
            final model = ConnectedUserModel.fromFirestore(
              sDoc.data() as Map<String, dynamic>,
              sId,
              'student',
            );
            results.add(model);
          }
        } catch (e) {
          debugPrint("Error loading profile for student $sId: $e");
        }
      }),
    );

    results.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return results;
  }

  Future<void> _acceptFollowRequest(ConnectedUserModel student) async {
    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      await _followService.acceptRequest(currentUserId, student.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Accepted ${student.name}'s request"),
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

  Future<void> _rejectFollowRequest(ConnectedUserModel student) async {
    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      await _followService.rejectRequest(currentUserId, student.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Declined ${student.name}'s request"),
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

  Future<void> _unfollowStudent(ConnectedUserModel student) async {
    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      await _followService.unfollowTeacher(currentUserId, student.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Removed ${student.name}"),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to remove. Please try again.")),
        );
      }
    }
  }

  void _openMessage(ConnectedUserModel student) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) return;

    final String chatRoomId =
        _chatService.getChatRoomId(currentUserId, student.uid);

    final String profileImage =
        (student.photoUrl != null && student.photoUrl!.isNotEmpty)
            ? student.photoUrl!
            : (student.profileImageUrl ?? '');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatRoomId: chatRoomId,
          receiverId: student.uid,
          receiverName: student.name,
          receiverProfilePic: profileImage,
          currentUserId: currentUserId,
          isTeacher: true,
        ),
      ),
    );
  }

  void _openProfile(ConnectedUserModel student) {
    Navigator.pushNamed(
      context,
      '/student_profile',
      arguments: {'studentId': student.uid},
    );
  }

  void _showActionMenu(ConnectedUserModel student) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ConnectionActionBottomSheet(
        user: student,
        onMessage: () => _openMessage(student),
        onUnfollowConfirm: () => _unfollowStudent(student),
      ),
    );
  }

  List<ConnectedUserModel> _filterList(List<ConnectedUserModel> source) {
    if (_searchQuery.isEmpty) return source;
    return source.where((s) {
      final name = s.name.toLowerCase();
      final sub = (s.subtitle ?? '').toLowerCase();
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
    final filteredFollowers = _filterList(_followersRequests);
    final filteredStudents = _filterList(_students);

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
                          "Student Network",
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
                                  hintText: 'Search students by name...',
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
                indicatorColor: tealPrimary,
                indicatorWeight: 3,
                labelColor: tealDark,
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
                        const Text("Followers"),
                        if (_followersRequests.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_followersRequests.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
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
                        const Text("Students"),
                        if (_students.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_students.length}',
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 11,
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
                  _FollowersTabView(
                    isLoading: _isFollowersLoading,
                    errorMessage: _followersError,
                    requests: filteredFollowers,
                    onRefresh: () async => _listenToNetwork(),
                    onAccept: _acceptFollowRequest,
                    onReject: _rejectFollowRequest,
                    onTapProfile: _openProfile,
                    skeletonBuilder: _buildSkeletonLoader,
                  ),
                  _StudentsTabView(
                    isLoading: _isStudentsLoading,
                    errorMessage: _studentsError,
                    students: filteredStudents,
                    onRefresh: () async => _listenToNetwork(),
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

class _FollowersTabView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<ConnectedUserModel> requests;
  final Future<void> Function() onRefresh;
  final Function(ConnectedUserModel) onAccept;
  final Function(ConnectedUserModel) onReject;
  final Function(ConnectedUserModel) onTapProfile;
  final Widget Function() skeletonBuilder;

  const _FollowersTabView({
    Key? key,
    required this.isLoading,
    required this.errorMessage,
    required this.requests,
    required this.onRefresh,
    required this.onAccept,
    required this.onReject,
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
                                    Icons.person_add_outlined,
                                    size: 68,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    "No followers yet",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    "Pending follow requests will appear here.",
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
                        final student = requests[index];
                        final hasPhoto = (student.photoUrl != null &&
                                student.photoUrl!.isNotEmpty) ||
                            (student.profileImageUrl != null &&
                                student.profileImageUrl!.isNotEmpty);
                        final String displayPhoto = (student.photoUrl != null &&
                                student.photoUrl!.isNotEmpty)
                            ? student.photoUrl!
                            : (student.profileImageUrl ?? '');

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
                                  onTap: () => onTapProfile(student),
                                  child: CircleAvatar(
                                    radius: 25,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    backgroundImage: hasPhoto
                                        ? NetworkImage(displayPhoto)
                                        : null,
                                    child: !hasPhoto
                                        ? Text(
                                            student.name.isNotEmpty
                                                ? student.name[0].toUpperCase()
                                                : 'S',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F766E),
                                              fontSize: 17,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => onTapProfile(student),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15.5,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          (student.subtitle != null &&
                                                  student.subtitle!.isNotEmpty)
                                              ? student.subtitle!
                                              : "Requested to follow you",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF10B981),
                                        size: 30,
                                      ),
                                      onPressed: () => onAccept(student),
                                      tooltip: 'Accept',
                                      splashRadius: 22,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.cancel_rounded,
                                        color: Color(0xFFEF4444),
                                        size: 30,
                                      ),
                                      onPressed: () => onReject(student),
                                      tooltip: 'Decline',
                                      splashRadius: 22,
                                    ),
                                  ],
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

class _StudentsTabView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<ConnectedUserModel> students;
  final Future<void> Function() onRefresh;
  final Function(ConnectedUserModel) onTapProfile;
  final Function(ConnectedUserModel) onMoreTap;
  final Widget Function() skeletonBuilder;

  const _StudentsTabView({
    Key? key,
    required this.isLoading,
    required this.errorMessage,
    required this.students,
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
              : students.isEmpty
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
                                    Icons.people_outline,
                                    size: 68,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    "No students yet",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    "Your connected students will appear here.",
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
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final student = students[index];
                        return ConnectedUserTile(
                          user: student,
                          onTap: () => onTapProfile(student),
                          onMoreTap: () => onMoreTap(student),
                        );
                      },
                    ),
    );
  }
}
