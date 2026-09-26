import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/success_toast.dart';
import 'teacher_profile_screen.dart'; 
import 'student_profile_screen.dart'; 

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isTeacher = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final teacherDoc = await _firestore.collection('teachers').doc(uid).get();
    if (mounted) {
      setState(() {
        isTeacher = teacherDoc.exists;
        isLoading = false;
      });
    }
  }

  Future<void> _handleRequest(String docId, String studentId, String teacherId, bool isAccepted) async {
    try {
      if (isAccepted) {
        await _firestore.collection('follow_requests').doc('${teacherId}_$studentId').set({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _firestore.collection('notifications').add({
          'receiverId': studentId,
          'senderId': teacherId,
          'senderName': _auth.currentUser?.displayName ?? 'Your Teacher',
          'senderPhotoUrl': _auth.currentUser?.photoURL ?? '',
          'message': 'accepted your follow request.',
          'type': 'request_accepted',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) SuccessToast.show(context, 'Request Accepted successfully!');
      } else {
        await _firestore.collection('follow_requests').doc('${teacherId}_$studentId').delete();
        if (mounted) SuccessToast.show(context, 'Request Rejected');
      }

      await _firestore.collection('notifications').doc(docId).delete();
    } catch (e) {
      debugPrint("Error handling request: $e");
    }
  }

  void _navigateToProfile(String senderId, String notificationType) async {
    if (senderId.isEmpty) return;

    if (notificationType == 'request_accepted') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeacherProfileScreen(currentUserId: senderId),
        ),
      );
    } else {
      final teacherDoc = await _firestore.collection('teachers').doc(senderId).get();
      if (!mounted) return;

      if (teacherDoc.exists) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TeacherProfileScreen(currentUserId: senderId)),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StudentProfileScreen(currentUserId: senderId)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFF1E4C7A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A)))
          : StreamBuilder<QuerySnapshot>(
              // ইনডেক্স এরর এড়ানোর জন্য orderBy বাদ দিয়ে ডাটা আনা হচ্ছে
              stream: _firestore.collection('notifications')
                  .where('receiverId', isEqualTo: currentUid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('No professional notifications yet.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                }

                // ইন-মেমোরি মেথডে লেটেস্ট নোটিফিকেশন উপরে সাজানো হচ্ছে
                final docs = snapshot.data!.docs;
                docs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final senderId = data['senderId'] ?? '';
                    final photoUrl = data['senderPhotoUrl'] ?? '';
                    final name = data['senderName'] ?? 'Someone';
                    final type = data['type'] ?? '';
                    final bool isRead = data['isRead'] ?? false;

                    if (!isRead) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _firestore.collection('notifications').doc(docId).update({'isRead': true});
                      });
                    }

                    return FadeInLeft(
                      duration: Duration(milliseconds: 200 + (index * 60)),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isRead ? Colors.white : const Color(0xFFEDF4FA),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3))],
                          border: isRead ? null : Border.all(color: const Color(0xFF1E4C7A).withOpacity(0.1), width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _navigateToProfile(senderId, type),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFFA2E8DD),
                                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                  child: photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _navigateToProfile(senderId, type),
                                      child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B1B1B))),
                                    ),
                                    const SizedBox(height: 3),
                                    Text('${data['message']}', style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.2)),

                                    if (type == 'follow_request' && isTeacher) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF1E4C7A),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              elevation: 0,
                                            ),
                                            onPressed: () => _handleRequest(docId, senderId, currentUid!, true),
                                            child: const Text('Accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                                          ),
                                          const SizedBox(width: 10),
                                          OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.redAccent,
                                              side: const BorderSide(color: Colors.redAccent, width: 1.2),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            onPressed: () => _handleRequest(docId, senderId, currentUid!, false),
                                            child: const Text('Reject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                                          ),
                                        ],
                                      )
                                    ]
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
          ),
    );
  }
}
