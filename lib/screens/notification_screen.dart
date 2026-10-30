import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/success_toast.dart';
import 'group/invitation_list_screen.dart';
import 'student_profile_screen.dart';
import 'teacher_profile_screen.dart';

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
  String _selectedFilter = 'all';

  static const Set<String> _allowedActivityTypes = {
    'follow_request',
    'request_accepted',
    'follow_accepted',
    'follow_rejected',
    'follow',
    'new_follower',
    'unfollow',
    'unfollowed',
    'group_dismissed',
    'group_dismiss',
    'group_removed',
    'student_removed',
    'group_invite',
    'group_invitation',
    'student_muted',
    'student_unmuted',
    'fee_reminder',
  };

  static const Set<String> _blockedChatTypes = {
    'chat',
    'message',
    'group_message',
    'group_chat',
    'text',
    'image',
    'video',
    'audio',
    'voice',
    'document',
    'file',
    'location',
  };

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _purgeExpiredNotifications();
  }

  Future<void> _checkUserRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final role = userDoc.data()!['role']?.toString().toLowerCase();
        if (mounted) {
          setState(() {
            isTeacher = role == 'teacher';
            isLoading = false;
          });
        }
        return;
      }

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

  Future<void> _purgeExpiredNotifications() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: uid)
          .get();

      final now = DateTime.now();
      final batch = _firestore.batch();
      bool hasDeletes = false;

      for (final doc in snap.docs) {
        final data = doc.data();
        final Timestamp? expireAt = data['expireAt'] as Timestamp?;
        final Timestamp? seenAt = data['seenAt'] as Timestamp?;

        bool isExpired = false;
        if (expireAt != null && expireAt.toDate().isBefore(now)) {
          isExpired = true;
        } else if (seenAt != null &&
            now.difference(seenAt.toDate()).inHours >= 48) {
          isExpired = true;
        }

        if (isExpired) {
          batch.delete(doc.reference);
          hasDeletes = true;
        }
      }

      if (hasDeletes) {
        await batch.commit();
      }
    } catch (_) {}
  }

  bool _isChatMessageNotification(Map<String, dynamic> data) {
    final String type = (data['type'] ?? data['notificationType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (_blockedChatTypes.contains(type)) return true;
    if (data.containsKey('chatRoomId') || data.containsKey('chatId')) return true;
    if (_allowedActivityTypes.contains(type)) return false;

    final String combinedText =
        '${data['message'] ?? ''} ${data['body'] ?? ''} ${data['title'] ?? ''}'
            .toLowerCase();

    final bool hasActivityKeyword = combinedText.contains('follow') ||
        combinedText.contains('unfollow') ||
        combinedText.contains('connect request') ||
        combinedText.contains('accepted your') ||
        combinedText.contains('dismiss') ||
        combinedText.contains('removed from') ||
        combinedText.contains('invited you') ||
        combinedText.contains('group') ||
        combinedText.contains('muted') ||
        combinedText.contains('tuition') ||
        combinedText.contains('fee');

    return !hasActivityKeyword;
  }

  bool _matchesSelectedFilter(Map<String, dynamic> data) {
    if (_selectedFilter == 'all') return true;

    final String type = (data['type'] ?? '').toString().toLowerCase();
    final String text =
        '${data['message'] ?? ''} ${data['body'] ?? ''}'.toLowerCase();

    final bool isGroupEvent = type.contains('group') ||
        type.contains('dismiss') ||
        type.contains('remove') ||
        type.contains('mute') ||
        type.contains('invite') ||
        text.contains('group');

    final bool isFollowEvent = type.contains('follow') ||
        type.contains('connect') ||
        text.contains('follow') ||
        text.contains('unfollow');

    if (_selectedFilter == 'group') return isGroupEvent;
    if (_selectedFilter == 'follow') return isFollowEvent;

    return true;
  }

  String _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  String _resolveNotificationMessage(Map<String, dynamic> data) {
    final String type = (data['type'] ?? '').toString().trim().toLowerCase();
    final String groupName = (data['groupName'] ?? '').toString().trim();

    if (type == 'group_dismissed' || type == 'group_dismiss') {
      return groupName.isNotEmpty
          ? 'dismissed the batch group "$groupName".'
          : 'dismissed the batch group.';
    }
    if (type == 'group_removed' || type == 'student_removed') {
      return groupName.isNotEmpty
          ? 'removed you from the group "$groupName".'
          : 'removed you from the group.';
    }
    if (type == 'group_invite' || type == 'group_invitation') {
      return groupName.isNotEmpty
          ? 'invited you to join the batch group "$groupName".'
          : 'invited you to join a batch group.';
    }
    if (type == 'unfollow' || type == 'unfollowed') {
      return 'has unfollowed you.';
    }
    if (type == 'follow' || type == 'new_follower') {
      return 'started following you.';
    }
    if (type == 'follow_request') {
      return 'sent you a connect request.';
    }
    if (type == 'request_accepted' || type == 'follow_accepted') {
      return 'accepted your connect request.';
    }
    if (type == 'follow_rejected') {
      return 'declined your follow request.';
    }
    if (type == 'student_muted') {
      return groupName.isNotEmpty
          ? 'muted your messaging in "$groupName".'
          : 'temporarily muted you in the group.';
    }
    if (type == 'student_unmuted') {
      return groupName.isNotEmpty
          ? 'unmuted you in "$groupName".'
          : 'unmuted you in the group.';
    }
    if (type == 'fee_reminder') {
      return 'sent a tuition fee reminder.';
    }

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

    return 'sent you an academic update.';
  }

  _NotificationBadgeStyle _getBadgeStyle(String type, String messageText) {
    final t = type.toLowerCase();
    final msg = messageText.toLowerCase();

    if (t.contains('unfollow') || msg.contains('unfollow')) {
      return const _NotificationBadgeStyle(
        icon: Icons.person_remove_alt_1_rounded,
        color: Color(0xFFE11D48),
        bgColor: Color(0xFFFFE4E6),
        tagLabel: 'Unfollowed',
      );
    }
    if (t.contains('dismiss') || msg.contains('dismiss')) {
      return const _NotificationBadgeStyle(
        icon: Icons.cancel_rounded,
        color: Color(0xFFDC2626),
        bgColor: Color(0xFFFEE2E2),
        tagLabel: 'Group Dismissed',
      );
    }
    if (t.contains('remove') || msg.contains('removed')) {
      return const _NotificationBadgeStyle(
        icon: Icons.group_off_rounded,
        color: Color(0xFFEA580C),
        bgColor: Color(0xFFFFEDD5),
        tagLabel: 'Removed from Group',
      );
    }
    if (t.contains('invite') || msg.contains('invited')) {
      return const _NotificationBadgeStyle(
        icon: Icons.group_add_rounded,
        color: Color(0xFF0D9488),
        bgColor: Color(0xFFCCFBF1),
        tagLabel: 'Group Invitation',
      );
    }
    if (t == 'request_accepted' || t == 'follow_accepted') {
      return const _NotificationBadgeStyle(
        icon: Icons.how_to_reg_rounded,
        color: Color(0xFF16A34A),
        bgColor: Color(0xFFDCFCE7),
        tagLabel: 'Connected',
      );
    }
    if (t == 'follow_rejected') {
      return const _NotificationBadgeStyle(
        icon: Icons.person_off_rounded,
        color: Color(0xFF64748B),
        bgColor: Color(0xFFF1F5F9),
        tagLabel: 'Declined',
      );
    }
    if (t == 'follow_request') {
      return const _NotificationBadgeStyle(
        icon: Icons.person_add_alt_1_rounded,
        color: Color(0xFF0284C7),
        bgColor: Color(0xFFE0F2FE),
        tagLabel: 'Follow Request',
      );
    }
    if (t == 'follow' || t == 'new_follower') {
      return const _NotificationBadgeStyle(
        icon: Icons.person_add_alt_1_rounded,
        color: Color(0xFF0284C7),
        bgColor: Color(0xFFE0F2FE),
        tagLabel: 'New Follower',
      );
    }
    if (t.contains('mute')) {
      return const _NotificationBadgeStyle(
        icon: Icons.mic_off_rounded,
        color: Color(0xFFD97706),
        bgColor: Color(0xFFFEF3C7),
        tagLabel: 'Group Moderation',
      );
    }
    return const _NotificationBadgeStyle(
      icon: Icons.notifications_active_rounded,
      color: Color(0xFF1E4C7A),
      bgColor: Color(0xFFEFF6FF),
      tagLabel: 'Activity Update',
    );
  }

  Future> _resolveSenderInfo(
      String senderId, Map<String, dynamic> data) async {
    String name =
        (data['senderName'] ?? data['teacherName'] ?? data['title'] ?? '')
            .toString()
            .trim();
    String photoUrl =
        (data['senderPhotoUrl'] ?? data['senderPhoto'] ?? '')
            .toString()
            .trim();

    if (name.isNotEmpty &&
        name != 'Someone' &&
        name != 'New Message' &&
        name != 'User') {
      return {'name': name, 'photoUrl': photoUrl};
    }

    if (senderId.isEmpty) {
      return {
        'name': name.isEmpty ? 'FYBTT Update' : name,
        'photoUrl': photoUrl,
      };
    }

    try {
      var userDoc = await _firestore.collection('users').doc(senderId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final d = userDoc.data()!;
        final resolvedName = (d['fullName'] ?? d['name'] ?? d['displayName'] ?? name).toString();
        if (resolvedName.isNotEmpty && resolvedName != 'User') {
          return {
            'name': resolvedName,
            'photoUrl': (d['profileImageUrl'] ?? d['profilePic'] ?? d['photoUrl'] ?? photoUrl).toString(),
          };
        }
      }

      var doc = await _firestore.collection('students').doc(senderId).get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        return {
          'name': (d['fullName'] ?? d['name'] ?? name).toString(),
          'photoUrl': (d['profileImageUrl'] ?? d['profilePic'] ?? photoUrl).toString(),
        };
      }

      doc = await _firestore.collection('teachers').doc(senderId).get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        return {
          'name': (d['fullName'] ?? d['name'] ?? name).toString(),
          'photoUrl': (d['profileImageUrl'] ?? d['profilePic'] ?? photoUrl).toString(),
        };
      }
    } catch (_) {}

    return {
      'name': name.isEmpty ? 'User' : name,
      'photoUrl': photoUrl,
    };
  }

  Future<void> _handleRequest(
      String docId, String studentId, String teacherId, bool isAccepted) async {
    try {
      if (isAccepted) {
        await _firestore
            .collection('follow_requests')
            .doc('${teacherId}_$studentId')
            .set({
          'teacherId': teacherId,
          'studentId': studentId,
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
          'status': 'unread',
          'createdAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          SuccessToast.show(context, 'Request Accepted successfully!');
        }
      } else {
        await _firestore
            .collection('follow_requests')
            .doc('${teacherId}_$studentId')
            .delete();
        if (mounted) SuccessToast.show(context, 'Request Declined');
      }

      await _firestore.collection('notifications').doc(docId).delete();
    } catch (_) {}
  }

  Future<void> _clearAllNotifications(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;
    try {
      final batch = _firestore.batch();
      for (final d in docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (mounted) {
        SuccessToast.show(context, 'All notifications cleared');
      }
    } catch (_) {}
  }

  void _navigateToTarget(String senderId, String notificationType) async {
    final currentUid = _auth.currentUser?.uid ?? '';
    final t = notificationType.toLowerCase();

    if (t.contains('invite') && currentUid.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvitationListScreen(currentUserId: currentUid),
        ),
      );
      return;
    }

    if (senderId.isEmpty) return;

    if (t == 'follow_request' ||
        t == 'follow' ||
        t == 'new_follower' ||
        t == 'unfollow' ||
        t == 'unfollowed') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentProfileScreen(currentUserId: senderId),
        ),
      );
      return;
    }

    if (t == 'request_accepted' ||
        t == 'follow_accepted' ||
        t.contains('dismiss')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeacherProfileScreen(currentUserId: senderId),
        ),
      );
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(senderId).get();
      if (!mounted) return;

      if (userDoc.exists && userDoc.data() != null) {
        final role = userDoc.data()!['role']?.toString().toLowerCase();
        if (role == 'teacher') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherProfileScreen(currentUserId: senderId),
            ),
          );
          return;
        } else if (role == 'student') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentProfileScreen(currentUserId: senderId),
            ),
          );
          return;
        }
      }

      final studentDoc =
          await _firestore.collection('students').doc(senderId).get();
      if (!mounted) return;

      if (studentDoc.exists &&
          studentDoc.data() != null &&
          (studentDoc.data()!['name'] != null ||
              studentDoc.data()!['fullName'] != null)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentProfileScreen(currentUserId: senderId),
          ),
        );
        return;
      }

      final teacherDoc =
          await _firestore.collection('teachers').doc(senderId).get();
      if (!mounted) return;

      if (teacherDoc.exists &&
          teacherDoc.data() != null &&
          (teacherDoc.data()!['name'] != null ||
              teacherDoc.data()!['fullName'] != null)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherProfileScreen(currentUserId: senderId),
          ),
        );
        return;
      }
    } catch (_) {}

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentProfileScreen(currentUserId: senderId),
        ),
      );
    }
  }

  Widget _buildFilterChipBar() {
    final List> filters = [
      {'key': 'all', 'label': 'All Updates', 'icon': Icons.all_inbox_rounded},
      {
        'key': 'follow',
        'label': 'Follow & Unfollow',
        'icon': Icons.people_alt_rounded
      },
      {
        'key': 'group',
        'label': 'Group Alerts',
        'icon': Icons.groups_rounded
      },
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final bool isSel = _selectedFilter == f['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(
                  f['icon'] as IconData,
                  size: 16,
                  color: isSel ? Colors.white : const Color(0xFF475569),
                ),
                label: Text(f['label'] as String),
                selected: isSel,
                selectedColor: const Color(0xFF1E4C7A),
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : const Color(0xFF334155),
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSel
                        ? const Color(0xFF1E4C7A)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                onSelected: (_) {
                  setState(() => _selectedFilter = f['key'] as String);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Activity Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E4C7A)),
            )
          : Column(
              children: [
                _buildFilterChipBar(),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('notifications')
                        .where('receiverId', isEqualTo: currentUid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load notifications.',
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF1E4C7A)),
                        );
                      }

                      final allDocs = snapshot.data?.docs ?? const [];
                      final now = DateTime.now();

                      final activityDocs = allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        final Timestamp? expireAt =
                            data['expireAt'] as Timestamp?;
                        if (expireAt != null &&
                            expireAt.toDate().isBefore(now)) {
                          doc.reference.delete().catchError((_) {});
                          return false;
                        }

                        final Timestamp? seenAt = data['seenAt'] as Timestamp?;
                        if (seenAt != null &&
                            now.difference(seenAt.toDate()).inHours >= 48) {
                          doc.reference.delete().catchError((_) {});
                          return false;
                        }

                        if (_isChatMessageNotification(data)) return false;
                        return _matchesSelectedFilter(data);
                      }).toList();

                      if (activityDocs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E4C7A)
                                        .withOpacity(0.07),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                    size: 54,
                                    color: Color(0xFF1E4C7A),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No activity notifications',
                                  style: TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Follow requests, unfollows, group invitations, and teacher group dismissal alerts will appear here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      activityDocs.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aTime = (aData['timestamp'] ?? aData['createdAt'])
                            as Timestamp?;
                        final bTime = (bData['timestamp'] ?? bData['createdAt'])
                            as Timestamp?;
                        if (aTime == null || bTime == null) return 0;
                        return bTime.compareTo(aTime);
                      });

                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${activityDocs.length} Notification${activityDocs.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: Colors.redAccent,
                                  ),
                                  onPressed: () =>
                                      _clearAllNotifications(activityDocs),
                                  icon: const Icon(Icons.clear_all_rounded,
                                      size: 17),
                                  label: const Text(
                                    'Clear All',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              physics: const BouncingScrollPhysics(),
                              itemCount: activityDocs.length,
                              itemBuilder: (context, index) {
                                final data = activityDocs[index].data()
                                    as Map<String, dynamic>;
                                final docId = activityDocs[index].id;
                                final senderId =
                                    data['senderId']?.toString() ?? '';
                                final type = data['type']?.toString() ?? '';
                                final bool isRead =
                                    data['isRead'] as bool? ?? false;
                                final Timestamp? timeStamp =
                                    (data['timestamp'] ?? data['createdAt'])
                                        as Timestamp?;
                                final timeAgo = _formatTimeAgo(timeStamp);
                                final messageText =
                                    _resolveNotificationMessage(data);
                                final badgeStyle =
                                    _getBadgeStyle(type, messageText);

                                if (!isRead) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _firestore
                                        .collection('notifications')
                                        .doc(docId)
                                        .update({
                                      'isRead': true,
                                      'status': 'read',
                                      'seenAt': FieldValue.serverTimestamp(),
                                      'expireAt': Timestamp.fromDate(
                                        DateTime.now().add(const Duration(days: 2)),
                                      ),
                                    }).catchError((_) {});
                                  });
                                }

                                return FutureBuilder>(
                                  future: _resolveSenderInfo(senderId, data),
                                  builder: (context, infoSnapshot) {
                                    final senderName =
                                        infoSnapshot.data?['name'] ?? 'User';
                                    final senderPhoto =
                                        infoSnapshot.data?['photoUrl'] ?? '';

                                    return FadeInLeft(
                                      duration: Duration(
                                          milliseconds:
                                              150 + (index.clamp(0, 8) * 35)),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: GenieDismissible(
                                          key: ValueKey(docId),
                                          onDismissed: () async {
                                            await _firestore
                                                .collection('notifications')
                                                .doc(docId)
                                                .delete();
                                          },
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            onTap: () => _navigateToTarget(
                                                senderId, type),
                                            child: Container(
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: isRead
                                                    ? Colors.white
                                                    : const Color(0xFFF0F7FF),
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: isRead
                                                      ? const Color(0xFFE2E8F0)
                                                      : const Color(0xFFBAE6FD),
                                                  width: 1.2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.025),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _navigateToTarget(
                                                            senderId, type),
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        CircleAvatar(
                                                          radius: 25,
                                                          backgroundColor:
                                                              badgeStyle
                                                                  .bgColor,
                                                          backgroundImage:
                                                              senderPhoto
                                                                      .isNotEmpty
                                                                  ? NetworkImage(
                                                                      senderPhoto)
                                                                  : null,
                                                          child: senderPhoto
                                                                  .isEmpty
                                                              ? Text(
                                                                  senderName
                                                                          .isNotEmpty
                                                                      ? senderName[
                                                                              0]
                                                                          .toUpperCase()
                                                                      : 'U',
                                                                  style:
                                                                      TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: badgeStyle
                                                                        .color,
                                                                    fontSize:
                                                                        18,
                                                                  ),
                                                                )
                                                              : null,
                                                        ),
                                                        Positioned(
                                                          right: -2,
                                                          bottom: -2,
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(4),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: badgeStyle
                                                                  .color,
                                                              shape: BoxShape
                                                                  .circle,
                                                              border:
                                                                  Border.all(
                                                                color: Colors
                                                                    .white,
                                                                width: 2,
                                                              ),
                                                            ),
                                                            child: Icon(
                                                              badgeStyle.icon,
                                                              size: 11,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 13),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 7,
                                                                vertical: 2,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: badgeStyle
                                                                    .bgColor,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                              child: Text(
                                                                badgeStyle
                                                                    .tagLabel,
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: badgeStyle
                                                                      .color,
                                                                ),
                                                              ),
                                                            ),
                                                            const Spacer(),
                                                            if (timeAgo
                                                                .isNotEmpty)
                                                              Text(
                                                                timeAgo,
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade500,
                                                                  fontSize:
                                                                      11.5,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 6),
                                                        RichText(
                                                          maxLines: 3,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          text: TextSpan(
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 13.8,
                                                              color: Color(
                                                                  0xFF1E293B),
                                                              height: 1.35,
                                                            ),
                                                            children: [
                                                              TextSpan(
                                                                text:
                                                                    '$senderName ',
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Color(
                                                                      0xFF0F172A),
                                                                ),
                                                              ),
                                                              TextSpan(
                                                                text:
                                                                    messageText,
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (type ==
                                                                'follow_request' &&
                                                            isTeacher &&
                                                            currentUid !=
                                                                null) ...[
                                                          const SizedBox(
                                                              height: 12),
                                                          Row(
                                                            children: [
                                                              ElevatedButton
                                                                  .icon(
                                                                style: ElevatedButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                      const Color(
                                                                          0xFF0284C7),
                                                                  foregroundColor:
                                                                      Colors
                                                                          .white,
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            10),
                                                                  ),
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                    horizontal:
                                                                        16,
                                                                    vertical: 7,
                                                                  ),
                                                                  minimumSize:
                                                                      Size.zero,
                                                                  tapTargetSize:
                                                                      MaterialTapTargetSize
                                                                          .shrinkWrap,
                                                                  elevation: 0,
                                                                ),
                                                                onPressed: () =>
                                                                    _handleRequest(
                                                                  docId,
                                                                  senderId,
                                                                  currentUid,
                                                                  true,
                                                                ),
                                                                icon: const Icon(
                                                                    Icons
                                                                        .check_rounded,
                                                                    size: 16),
                                                                label:
                                                                    const Text(
                                                                  'Confirm',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        12.5,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              OutlinedButton(
                                                                style: OutlinedButton
                                                                    .styleFrom(
                                                                  foregroundColor:
                                                                      const Color(
                                                                          0xFF64748B),
                                                                  side: BorderSide(
                                                                      color: Colors
                                                                          .grey
                                                                          .shade300),
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            10),
                                                                  ),
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                    horizontal:
                                                                        16,
                                                                    vertical: 7,
                                                                  ),
                                                                  minimumSize:
                                                                      Size.zero,
                                                                  tapTargetSize:
                                                                      MaterialTapTargetSize
                                                                          .shrinkWrap,
                                                                ),
                                                                onPressed: () =>
                                                                    _handleRequest(
                                                                  docId,
                                                                  senderId,
                                                                  currentUid,
                                                                  false,
                                                                ),
                                                                child:
                                                                    const Text(
                                                                  'Delete',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        12.5,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                        if ((type ==
                                                                    'group_invite' ||
                                                                type ==
                                                                    'group_invitation') &&
                                                            currentUid !=
                                                                null) ...[
                                                          const SizedBox(
                                                              height: 10),
                                                          ElevatedButton.icon(
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  const Color(
                                                                      0xFF0F766E),
                                                              foregroundColor:
                                                                  Colors.white,
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 14,
                                                                vertical: 6,
                                                              ),
                                                              minimumSize:
                                                                  Size.zero,
                                                              tapTargetSize:
                                                                  MaterialTapTargetSize
                                                                      .shrinkWrap,
                                                              elevation: 0,
                                                            ),
                                                            onPressed: () =>
                                                                _navigateToTarget(
                                                                    senderId,
                                                                    type),
                                                            icon: const Icon(
                                                                Icons
                                                                    .mail_outline_rounded,
                                                                size: 15),
                                                            label: const Text(
                                                              'View Group Invite',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  if (!isRead)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                              left: 8, top: 4),
                                                      width: 9,
                                                      height: 9,
                                                      decoration:
                                                          const BoxDecoration(
                                                        color:
                                                            Color(0xFF0284C7),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _NotificationBadgeStyle {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String tagLabel;

  const _NotificationBadgeStyle({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.tagLabel,
  });
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

class _GenieDismissibleState extends State<GenieDismissible>
    with SingleTickerProviderStateMixin {
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
    _progress =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);

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
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.white, size: 24),
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
      size.height,
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