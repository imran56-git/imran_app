import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/success_toast.dart';
import 'teacher_profile_screen.dart'; // প্রয়োজন অনুযায়ী পাথ ঠিক করে নেবেন
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

    // ইউজার কি টিচার নাকি স্টুডেন্ট তা চেক করা হচ্ছে
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
        // এক্সেপ্ট করলে follow_requests এর স্ট্যাটাস accepted হবে এবং স্টুডেন্ট কাউন্ট হবে
        await _firestore.collection('follow_requests').doc('${studentId}_$teacherId').update({
          'status': 'accepted',
        });
        
        // স্টুডেন্টের কাছে ব্যাক-নোটিফিকেশন পাঠানো
        await _firestore.collection('notifications').add({
          'receiverId': studentId,
          'senderId': teacherId,
          'message': 'accepted your follow request.',
          'type': 'request_accepted',
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        SuccessToast.show(context, 'Request Accepted successfully!');
      } else {
        // রিজেক্ট করলে ডকুমেন্ট সরাসরি ডিলিট হয়ে যাবে
        await _firestore.collection('follow_requests').doc('${studentId}_$teacherId').delete();
        SuccessToast.show(context, 'Request Rejected');
      }
      
      // মূল নোটিফিকেশন মেইনস্ট্রিম থেকে রিমুভ করা
      await _firestore.collection('notifications').doc(docId).delete();
    } catch (e) {
      debugPrint("Error handling request: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E4C7A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A)))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('notifications')
                  .where('receiverId', isEqualTo: currentUid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('No professional notifications yet.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

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

                    // নোটিফিকেশনটি পড়া হয়েছে হিসেবে মার্ক করা
                    _firestore.collection('notifications').doc(docId).update({'isRead': true});

                    return FadeInLeft(
                      duration: Duration(milliseconds: 200 + (index * 100)),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // প্রোফাইল ফটো বা নামে ট্যাপ করলে প্রোফাইল ওপেন হবে
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StudentProfileScreen(currentUserId: senderId),
                                    ),
                                  );
                                },
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
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => StudentProfileScreen(currentUserId: senderId),
                                          ),
                                        );
                                      },
                                      child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text('${data['message']}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                    
                                    // যদি টাইপ 'follow_request' হয় এবং ইউজার টিচার হন তবেই Accept/Reject বাটন আসবে
                                    if (type == 'follow_request' && isTeacher) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF1E4C7A),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            onPressed: () => _handleRequest(docId, senderId, currentUid!, true),
                                            child: const Text('Accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.redAccent,
                                              side: const BorderSide(color: Colors.redAccent),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            onPressed: () => _handleRequest(docId, senderId, currentUid!, false),
                                            child: const Text('Reject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
