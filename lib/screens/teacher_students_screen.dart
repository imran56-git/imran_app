import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/connected_user_model.dart';
import '../widgets/connected_user_tile.dart';
import '../widgets/connection_action_bottom_sheet.dart';

class TeacherStudentsScreen extends StatefulWidget {
  const TeacherStudentsScreen({Key? key}) : super(key: key);

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isFollowersLoading = true;
  bool _isStudentsLoading = true;
  String? _followersError;
  String? _studentsError;

  List<ConnectedUserModel> _followersRequests = [];
  List<ConnectedUserModel> _students = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    await Future.wait([
      _fetchFollowersRequests(),
      _fetchStudents(),
    ]);
  }

  // 🟢 ১. পেন্ডিং ফলোয়ার্স রিকুয়েস্ট ফেচিং (Followers Tab)
  Future<void> _fetchFollowersRequests() async {
    if (!mounted) return;

    setState(() {
      _isFollowersLoading = _followersRequests.isEmpty;
      _followersError = null;
    });

    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        if (mounted) setState(() => _isFollowersLoading = false);
        return;
      }

      final collections = ['follow_requests', 'follow_req'];
      final Set<String> pendingSenderIds = {};

      for (String col in collections) {
        final snap = await _firestore
            .collection(col)
            .where('receiverId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'pending')
            .get();

        for (var doc in snap.docs) {
          final data = doc.data();
          if (data.containsKey('senderId')) {
            pendingSenderIds.add(data['senderId'].toString());
          }
        }
      }

      final loadedRequests = await Future.wait(
        pendingSenderIds.map((sId) async {
          DocumentSnapshot sDoc = await _firestore.collection('students').doc(sId).get();
          if (!sDoc.exists) {
            sDoc = await _firestore.collection('users').doc(sId).get();
          }

          if (sDoc.exists && sDoc.data() != null) {
            return ConnectedUserModel.fromFirestore(
              sDoc.data() as Map<String, dynamic>,
              sId,
              'student',
            );
          }
          return null;
        }),
      );

      if (mounted) {
        setState(() {
          _followersRequests = loadedRequests.whereType<ConnectedUserModel>().toList();
          _isFollowersLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _followersError = "Unable to load follow requests.";
          _isFollowersLoading = false;
        });
      }
    }
  }

  // 🟢 ২. অ্যাকসেপ্টেড স্টুডেন্টস ফেচিং (Students Tab)
  Future<void> _fetchStudents() async {
    if (!mounted) return;

    setState(() {
      _isStudentsLoading = _students.isEmpty;
      _studentsError = null;
    });

    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        if (mounted) setState(() => _isStudentsLoading = false);
        return;
      }

      final collections = ['follow_requests', 'follow_req'];
      final Set<String> studentIdsSet = {};

      for (String col in collections) {
        final snap1 = await _firestore
            .collection(col)
            .where('senderId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'accepted')
            .get();

        for (var doc in snap1.docs) {
          final data = doc.data();
          if (data.containsKey('receiverId')) {
            studentIdsSet.add(data['receiverId'].toString());
          }
        }

        final snap2 = await _firestore
            .collection(col)
            .where('receiverId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'accepted')
            .get();

        for (var doc in snap2.docs) {
          final data = doc.data();
          if (data.containsKey('senderId')) {
            studentIdsSet.add(data['senderId'].toString());
          }
        }
      }

      final loadedStudents = await Future.wait(
        studentIdsSet.map((sId) async {
          DocumentSnapshot sDoc = await _firestore.collection('students').doc(sId).get();
          if (!sDoc.exists) {
            sDoc = await _firestore.collection('users').doc(sId).get();
          }

          if (sDoc.exists && sDoc.data() != null) {
            return ConnectedUserModel.fromFirestore(
              sDoc.data() as Map<String, dynamic>,
              sId,
              'student',
            );
          }
          return null;
        }),
      );

      if (mounted) {
        setState(() {
          _students = loadedStudents.whereType<ConnectedUserModel>().toList();
          _isStudentsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _studentsError = "Unable to load students.";
          _isStudentsLoading = false;
        });
      }
    }
  }

  // 🟢 রিকুয়েস্ট অ্যাকসেপ্ট লজিক (Followers -> Students অটো শিফট)
  Future<void> _acceptFollowRequest(ConnectedUserModel student) async {
    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final collections = ['follow_requests', 'follow_req'];

      for (String col in collections) {
        final snap = await _firestore
            .collection(col)
            .where('senderId', isEqualTo: student.uid)
            .where('receiverId', isEqualTo: currentUserId)
            .get();

        for (var doc in snap.docs) {
          await doc.reference.update({'status': 'accepted', 'updatedAt': FieldValue.serverTimestamp()});
        }
      }

      if (mounted) {
        setState(() {
          _followersRequests.removeWhere((s) => s.uid == student.uid);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Accepted ${student.name}'s request")),
        );

        // স্টুডেন্ট লিস্ট রিলোড করে নতুন স্টুডেন্ট যোগ করা
        _fetchStudents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Action failed. Please try again.")),
        );
      }
    }
  }

  // 🟢 রিকুয়েস্ট রিজেক্ট লজিক
  Future<void> _rejectFollowRequest(ConnectedUserModel student) async {
    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final collections = ['follow_requests', 'follow_req'];

      for (String col in collections) {
        final snap = await _firestore
            .collection(col)
            .where('senderId', isEqualTo: student.uid)
            .where('receiverId', isEqualTo: currentUserId)
            .get();

        for (var doc in snap.docs) {
          await doc.reference.delete();
        }
      }

      if (mounted) {
        setState(() {
          _followersRequests.removeWhere((s) => s.uid == student.uid);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Declined ${student.name}'s request")),
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

      final collections = ['follow_requests', 'follow_req'];

      for (String col in collections) {
        final snap1 = await _firestore
            .collection(col)
            .where('senderId', isEqualTo: currentUserId)
            .where('receiverId', isEqualTo: student.uid)
            .get();
        for (var doc in snap1.docs) {
          await doc.reference.delete();
        }

        final snap2 = await _firestore
            .collection(col)
            .where('senderId', isEqualTo: student.uid)
            .where('receiverId', isEqualTo: currentUserId)
            .get();
        for (var doc in snap2.docs) {
          await doc.reference.delete();
        }
      }

      if (mounted) {
        setState(() {
          _students.removeWhere((s) => s.uid == student.uid);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Removed ${student.name}")),
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
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {'peerId': student.uid, 'peerName': student.name},
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
              decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 140, height: 14, color: Colors.grey.shade200),
                  const SizedBox(height: 6),
                  Container(width: 190, height: 12, color: Colors.grey.shade200),
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
        title: const Text("Student Network", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Followers"),
                  if (_followersRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: Text(
                        '${_followersRequests.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                  const Text("Students"),
                  if (_students.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_students.length}',
                        style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
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
          // 🟢 TAB ১: Followers Tab (Pending Requests)
          _FollowersTabView(
            isLoading: _isFollowersLoading,
            errorMessage: _followersError,
            requests: _followersRequests,
            onRefresh: _fetchFollowersRequests,
            onAccept: _acceptFollowRequest,
            onReject: _rejectFollowRequest,
            onTapProfile: _openProfile,
            skeletonBuilder: _buildSkeletonLoader,
          ),

          // 🟢 TAB ২: Students Tab (Accepted Connections)
          _StudentsTabView(
            isLoading: _isStudentsLoading,
            errorMessage: _studentsError,
            students: _students,
            onRefresh: _fetchStudents,
            onTapProfile: _openProfile,
            onMoreTap: _showActionMenu,
            skeletonBuilder: _buildSkeletonLoader,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🟢 Sub-Widget: Followers Tab View
// ---------------------------------------------------------------------------
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
      onRefresh: onRefresh,
      child: isLoading
          ? skeletonBuilder()
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage!, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: onRefresh, child: const Text("Retry")),
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
                                Icon(Icons.person_add_outlined, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text("No followers yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                SizedBox(height: 6),
                                Text("Pending follow requests will appear here.", style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final student = requests[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            onTap: () => onTapProfile(student),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundImage: student.profileImageUrl != null && student.profileImageUrl!.isNotEmpty
                                  ? NetworkImage(student.profileImageUrl!)
                                  : null,
                              child: student.profileImageUrl == null || student.profileImageUrl!.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(student.subtitle ?? "Requested to follow you", style: const TextStyle(fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                  onPressed: () => onAccept(student),
                                  tooltip: 'Accept',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 28),
                                  onPressed: () => onReject(student),
                                  tooltip: 'Decline',
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

// ---------------------------------------------------------------------------
// 🟢 Sub-Widget: Students Tab View
// ---------------------------------------------------------------------------
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
      onRefresh: onRefresh,
      child: isLoading
          ? skeletonBuilder()
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage!, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: onRefresh, child: const Text("Retry")),
                    ],
                  ),
                )
              : students.isEmpty
                  ? Center(
                      child: ListView(
                        shrinkWrap: true,
                        children: const [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text("No students yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                SizedBox(height: 6),
                                Text("Your connected students will appear here.", style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                  : ListView.builder(
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