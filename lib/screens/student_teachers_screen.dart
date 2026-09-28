import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/connected_user_model.dart';
import '../widgets/connected_user_tile.dart';
import '../widgets/connection_action_bottom_sheet.dart';

class StudentTeachersScreen extends StatefulWidget {
  const StudentTeachersScreen({Key? key}) : super(key: key);

  @override
  State<StudentTeachersScreen> createState() => _StudentTeachersScreenState();
}

class _StudentTeachersScreenState extends State<StudentTeachersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String? _errorMessage;
  List<ConnectedUserModel> _teachers = [];

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        setState(() {
          _errorMessage = "Authentication error. Please log in again.";
          _isLoading = false;
        });
        return;
      }

      QuerySnapshot followSnap = await _firestore
          .collection('follow_req')
          .where('senderId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      List<String> teacherIds = followSnap.docs.map((doc) => doc['receiverId'].toString()).toList();

      QuerySnapshot reverseSnap = await _firestore
          .collection('follow_req')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (var doc in reverseSnap.docs) {
        String sender = doc['senderId'].toString();
        if (!teacherIds.contains(sender)) {
          teacherIds.add(sender);
        }
      }

      List<ConnectedUserModel> loadedTeachers = [];

      for (String tId in teacherIds) {
        DocumentSnapshot tDoc = await _firestore.collection('teachers').doc(tId).get();
        if (!tDoc.exists) {
          tDoc = await _firestore.collection('users').doc(tId).get();
        }

        if (tDoc.exists && tDoc.data() != null) {
          loadedTeachers.add(
            ConnectedUserModel.fromFirestore(tDoc.data() as Map<String, dynamic>, tId, 'teacher'),
          );
        }
      }

      if (mounted) {
        setState(() {
          _teachers = loadedTeachers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Unable to load teachers.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unfollowTeacher(ConnectedUserModel teacher) async {
    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      QuerySnapshot snap1 = await _firestore
          .collection('follow_req')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: teacher.uid)
          .get();

      for (var doc in snap1.docs) {
        await doc.reference.delete();
      }

      QuerySnapshot snap2 = await _firestore
          .collection('follow_req')
          .where('senderId', isEqualTo: teacher.uid)
          .where('receiverId', isEqualTo: currentUserId)
          .get();

      for (var doc in snap2.docs) {
        await doc.reference.delete();
      }

      setState(() {
        _teachers.removeWhere((t) => t.uid == teacher.uid);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unfollowed ${teacher.name}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to unfollow. Please try again.")),
        );
      }
    }
  }

  void _openMessage(ConnectedUserModel teacher) {
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {'peerId': teacher.uid, 'peerName': teacher.name},
    ).catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to open chat. Please try again.")),
        );
      }
    });
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
        title: const Text("Teachers", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTeachers,
        child: _isLoading
            ? _buildSkeletonLoader()
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage!, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchTeachers,
                          child: const Text("Retry"),
                        )
                      ],
                    ),
                  )
                : _teachers.isEmpty
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
                                  Text("No teachers yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 6),
                                  Text("Connect with teachers to see them here.", style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _teachers.length,
                        itemBuilder: (context, index) {
                          final teacher = _teachers[index];
                          return ConnectedUserTile(
                            user: teacher,
                            onTap: () => _openProfile(teacher),
                            onMoreTap: () => _showActionMenu(teacher),
                          );
                        },
                      ),
      ),
    );
  }
}
