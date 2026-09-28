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

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String? _errorMessage;
  List<ConnectedUserModel> _students = [];

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
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

      List<String> studentIds = followSnap.docs.map((doc) => doc['receiverId'].toString()).toList();

      QuerySnapshot reverseSnap = await _firestore
          .collection('follow_req')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (var doc in reverseSnap.docs) {
        String sender = doc['senderId'].toString();
        if (!studentIds.contains(sender)) {
          studentIds.add(sender);
        }
      }

      List<ConnectedUserModel> loadedStudents = [];

      for (String sId in studentIds) {
        DocumentSnapshot sDoc = await _firestore.collection('students').doc(sId).get();
        if (!sDoc.exists) {
          sDoc = await _firestore.collection('users').doc(sId).get();
        }

        if (sDoc.exists && sDoc.data() != null) {
          loadedStudents.add(
            ConnectedUserModel.fromFirestore(sDoc.data() as Map<String, dynamic>, sId, 'student'),
          );
        }
      }

      if (mounted) {
        setState(() {
          _students = loadedStudents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Unable to load students.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unfollowStudent(ConnectedUserModel student) async {
    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      QuerySnapshot snap1 = await _firestore
          .collection('follow_req')
          .where('senderId', isEqualTo: currentUserId)
          .where('receiverId', isEqualTo: student.uid)
          .get();

      for (var doc in snap1.docs) {
        await doc.reference.delete();
      }

      QuerySnapshot snap2 = await _firestore
          .collection('follow_req')
          .where('senderId', isEqualTo: student.uid)
          .where('receiverId', isEqualTo: currentUserId)
          .get();

      for (var doc in snap2.docs) {
        await doc.reference.delete();
      }

      setState(() {
        _students.removeWhere((s) => s.uid == student.uid);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unfollowed ${student.name}")),
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

  void _openMessage(ConnectedUserModel student) {
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {'peerId': student.uid, 'peerName': student.name},
    ).catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to open chat. Please try again.")),
        );
      }
    });
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
        title: const Text("Students", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStudents,
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
                          onPressed: _fetchStudents,
                          child: const Text("Retry"),
                        )
                      ],
                    ),
                  )
                : _students.isEmpty
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
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          final student = _students[index];
                          return ConnectedUserTile(
                            user: student,
                            onTap: () => _openProfile(student),
                            onMoreTap: () => _showActionMenu(student),
                          );
                        },
                      ),
      ),
    );
  }
}
