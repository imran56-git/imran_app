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

    try {
      final teacherDoc = await _firestore.collection('teachers').doc(uid).get();
      if (mounted) {
        setState(() {
          isTeacher = teacherDoc.exists;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  String _resolveNotificationMessage(Map<String, dynamic> data) {
    final message = data['message']?.toString().trim();
    if (message != null && message.isNotEmpty && message != 'null') {
      return message;
    }
    final body = data['body']?.toString().trim();
    if (body != null && body.isNotEmpty && body != 'null') {
      return body;
    }
    final title = data['title']?.toString().trim();
    if (title != null && title.isNotEmpty && title != 'null') {
      return title;
    }

    final type = data['type']?.toString() ?? '';
    if (type == 'follow_request') return 'sent you a connect request.';
    if (type == 'request_accepted') return 'accepted your connect request.';
    if (type == 'chat') return 'sent you a new message.';
    if (type == 'fee_reminder') return 'sent a tuition fee reminder.';
    return 'sent you an update.';
  }

  Future<Map<String, String>> _resolveSenderInfo(String senderId, Map<String, dynamic> data) async {
    String name = (data['senderName'] ?? data['title'] ?? '').toString().trim();
    String photoUrl = (data['senderPhotoUrl'] ?? '').toString().trim();

    if (name.isNotEmpty && name != 'Someone' && name != 'New Message' && photoUrl.isNotEmpty) {
      return {'name': name, 'photoUrl': photoUrl};
    }

    if (senderId.isEmpty) {
      return {
        'name': name.isEmpty ? 'User' : name,
        'photoUrl': photoUrl,
      };
    }

    try {
      var doc = await _firestore.collection('teachers').doc(senderId).get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        return {
          'name': d['fullName'] ?? d['name'] ?? name,
          'photoUrl': d['profileImageUrl'] ?? d['profilePic'] ?? photoUrl,
        };
      }

      doc = await _firestore.collection('students').doc(senderId).get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        return {
          'name': d['fullName'] ?? d['name'] ?? name,
          'photoUrl': d['profileImageUrl'] ?? d['profilePic'] ?? photoUrl,
        };
      }

      doc = await _firestore.collection('users').doc(senderId).get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        return {
          'name': d['fullName'] ?? d['name'] ?? d['displayName'] ?? name,
          'photoUrl': d['profileImageUrl'] ?? d['profilePic'] ?? d['photoUrl'] ?? photoUrl,
        };
      }
    } catch (_) {}

    return {
      'name': name.isEmpty ? 'User' : name,
      'photoUrl': photoUrl,
    };
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
          'message': 'accepted your connect request.',
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
    } catch (_) {}
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A)))
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('notifications')
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 68, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications yet',
                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Updates and requests will appear here.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = (aData['timestamp'] ?? aData['createdAt']) as Timestamp?;
                  final bTime = (bData['timestamp'] ?? bData['createdAt']) as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final senderId = data['senderId']?.toString() ?? '';
                    final type = data['type']?.toString() ?? '';
                    final bool isRead = data['isRead'] as bool? ?? false;
                    final Timestamp? timeStamp = (data['timestamp'] ?? data['createdAt']) as Timestamp?;
                    final timeAgo = _formatTimeAgo(timeStamp);
                    final messageText = _resolveNotificationMessage(data);

                    if (!isRead) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _firestore.collection('notifications').doc(docId).update({'isRead': true}).catchError((_) {});
                      });
                    }

                    return FutureBuilder<Map<String, String>>(
                      future: _resolveSenderInfo(senderId, data),
                      builder: (context, infoSnapshot) {
                        final senderName = infoSnapshot.data?['name'] ?? 'User';
                        final senderPhoto = infoSnapshot.data?['photoUrl'] ?? '';

                        return FadeInLeft(
                          duration: Duration(milliseconds: 150 + (index * 40)),
                          child: GenieDismissible(
                            key: ValueKey(docId),
                            onDismissed: () async {
                              await _firestore.collection('notifications').doc(docId).delete();
                            },
                            child: Container(
                              color: isRead ? Colors.white : const Color(0xFFF0F7FF),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () => _navigateToProfile(senderId, type),
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      backgroundImage: senderPhoto.isNotEmpty ? NetworkImage(senderPhoto) : null,
                                      child: senderPhoto.isEmpty
                                          ? Text(
                                              senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 17),
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          text: TextSpan(
                                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), height: 1.3),
                                            children: [
                                              TextSpan(
                                                text: '$senderName ',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              TextSpan(
                                                text: messageText,
                                                style: const TextStyle(fontWeight: FontWeight.normal),
                                              ),
                                              if (timeAgo.isNotEmpty)
                                                TextSpan(
                                                  text: '  $timeAgo',
                                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (type == 'follow_request' && isTeacher && currentUid != null) ...[
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF0284C7),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  elevation: 0,
                                                ),
                                                onPressed: () => _handleRequest(docId, senderId, currentUid, true),
                                                child: const Text('Confirm', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFF64748B),
                                                  side: BorderSide(color: Colors.grey.shade300),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                onPressed: () => _handleRequest(docId, senderId, currentUid, false),
                                                child: const Text('Delete', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                              ),
                                            ],
                                          )
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0284C7),
                                        shape: BoxShape.circle,
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
                );
              },
            ),
    );
  }
}

class GenieDismissible extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismissed;

  const GenieDismissible({
    super.key,
    required this.child,
    required this.onDismissed,
  });

  @override
  State<GenieDismissible> createState() => _GenieDismissibleState();
}

class _GenieDismissibleState extends State<GenieDismissible> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (mounted) {
      setState(() {
        _isDismissing = true;
      });
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemKey = widget.key ?? UniqueKey();

    if (!_isDismissing) {
      return Dismissible(
        key: itemKey,
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          _dismiss();
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: const Color(0xFFEF4444),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final val = _progress.value;
        return Opacity(
          opacity: (1 - val).clamp(0.0, 1.0),
          child: ClipPath(
            clipper: GenieClipper(progress: val),
            child: Transform(
              alignment: Alignment.bottomRight,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..scale(1.0 - (val * 0.7), 1.0 - (val * 0.95)),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

class GenieClipper extends CustomClipper<Path> {
  final double progress;

  GenieClipper({required this.progress});

  @override
  Path getClip(Size size) {
    Path path = Path();
    double topRightShift = size.width * progress * 0.8;
    double bottomRightShift = size.width * progress;

    path.moveTo(0, 0);
    path.lineTo(size.width - topRightShift, 0);

    path.quadraticBezierTo(
      size.width * (1 - progress * 0.5), 
      size.height * 0.5, 
      size.width - bottomRightShift, 
      size.height
    );

    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant GenieClipper oldDelegate) {
    return oldDelegate.progress != progress;
  }
}