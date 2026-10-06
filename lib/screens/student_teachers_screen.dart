import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/connected_user_model.dart';
import '../services/follow_service.dart';
import '../widgets/connected_user_tile.dart';
import '../widgets/connection_action_bottom_sheet.dart';

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

  StreamSubscription? _requestsSubscription;

  bool _isFollowingLoading = true;
  bool _isTeachersLoading = true;
  String? _followingError;
  String? _teachersError;

  List<ConnectedUserModel> _followingRequests = [];
  List<ConnectedUserModel> _myTeachers = [];

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
              content: Text("Cancelled follow request to ${teacher.name}")),
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
          SnackBar(content: Text("Unfollowed ${teacher.name}")),
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
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {'peerId': teacher.uid, 'peerName': teacher.name},
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

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200, shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 140, height: 14, color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Container(
                      width: 190, height: 12, color: Colors.grey.shade200),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Connections",
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Following"),
                  if (_followingRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_followingRequests.length}',
                        style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("My Teachers"),
                  if (_myTeachers.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_myTeachers.length}',
                        style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FollowingTabView(
            isLoading: _isFollowingLoading,
            errorMessage: _followingError,
            requests: _followingRequests,
            onRefresh: () async => _listenToConnections(),
            onCancel: _cancelFollowRequest,
            onTapProfile: _openProfile,
            skeletonBuilder: _buildSkeletonLoader,
          ),
          _MyTeachersTabView(
            isLoading: _isTeachersLoading,
            errorMessage: _teachersError,
            teachers: _myTeachers,
            onRefresh: () async => _listenToConnections(),
            onTapProfile: _openProfile,
            onMoreTap: _showActionMenu,
            skeletonBuilder: _buildSkeletonLoader,
          ),
        ],
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
      onRefresh: onRefresh,
      child: isLoading
          ? skeletonBuilder()
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage!,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: onRefresh, child: const Text("Retry")),
                    ],
                  ),
                )
              : requests.isEmpty
                  ? Center(
                      child: ListView(
                        shrinkWrap: true,
                        children: const [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_search_outlined,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text("No pending requests",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 6),
                                Text(
                                    "Teachers you requested to follow will show here.",
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final teacher = requests[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            onTap: () => onTapProfile(teacher),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundImage: teacher.profileImageUrl != null &&
                                      teacher.profileImageUrl!.isNotEmpty
                                  ? NetworkImage(teacher.profileImageUrl!)
                                  : null,
                              child: teacher.profileImageUrl == null ||
                                      teacher.profileImageUrl!.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(teacher.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                (teacher.subtitle != null &&
                                        teacher.subtitle!.isNotEmpty)
                                    ? teacher.subtitle!
                                    : "Request pending approval",
                                style: const TextStyle(fontSize: 12)),
                            trailing: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(
                                    color: Colors.redAccent),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: () => onCancel(teacher),
                              child: const Text("Cancel",
                                  style: TextStyle(fontSize: 12)),
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
      onRefresh: onRefresh,
      child: isLoading
          ? skeletonBuilder()
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage!,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: onRefresh, child: const Text("Retry")),
                    ],
                  ),
                )
              : teachers.isEmpty
                  ? Center(
                      child: ListView(
                        shrinkWrap: true,
                        children: const [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.school_outlined,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text("No teachers yet",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 6),
                                Text(
                                    "Connect with teachers to see them here.",
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                  : ListView.builder(
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
