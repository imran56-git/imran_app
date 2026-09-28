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

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> with AutomaticKeepAliveClientMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String? _errorMessage;
  List<ConnectedUserModel> _students = [];

  @override
  bool get wantKeepAlive => true; // ট্যাব পরিবর্তন করলেও স্টেট ধরে রাখবে

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = _students.isEmpty; // আগে থেকে ডাটা থাকলে লোডার দেখাবে না
      _errorMessage = null;
    });

    try {
      final String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        if (mounted) {
          setState(() {
            _errorMessage = "Authentication error. Please log in again.";
            _isLoading = false;
          });
        }
        return;
      }

      // follow_requests এবং follow_req উভয় কালেকশন থেকেই প্যারাল্যালের মাধ্যমে চেক করা
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

      final List<String> studentIds = studentIdsSet.toList();

      // Future.wait ব্যবহার করে সব স্টুডেন্টের তথ্য একসাথে (Parallel) দ্রুত ফেচ করা
      final loadedStudents = await Future.wait(
        studentIds.map((sId) async {
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

      final collections = ['follow_requests', 'follow_req'];

      for (String col in collections) {
        final docRef1 = _firestore.collection(col).doc('${currentUserId}_${student.uid}');
        final docRef2 = _firestore.collection(col).doc('${student.uid}_$currentUserId');
        await docRef1.delete();
        await docRef2.delete();

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
    super.build(context); // AutomaticKeepAliveClientMixin-এর জন্য অত্যন্ত জরুরি

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
