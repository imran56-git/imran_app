import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/group_model.dart';
import '../models/invitation_model.dart';
import '../models/message_model.dart';
import 'local_chat_storage_service.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final LocalChatStorageService _localStorage = LocalChatStorageService();

  Future<bool> _verifySingleAdmin(String groupId, String userId) async {
    if (groupId.trim().isEmpty || userId.trim().isEmpty) return false;
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (!doc.exists || doc.data() == null) return false;
    final data = doc.data()!;
    final String creatorId =
        (data['createdBy'] ?? data['teacherId'] ?? data['adminId'] ?? '')
            .toString();
    return creatorId.isNotEmpty && creatorId == userId;
  }

  List<String> _extractMediaUrlsFromData(Map<String, dynamic> data) {
    final List<String> urls = <String>[];
    final mediaUrl = data['mediaUrl']?.toString();
    if (mediaUrl != null && mediaUrl.startsWith('http')) urls.add(mediaUrl);

    if (data['mediaUrls'] is List) {
      for (final item in data['mediaUrls']) {
        final s = item.toString();
        if (s.startsWith('http') && !urls.contains(s)) urls.add(s);
      }
    }

    if (data['mediaMetaData'] is Map) {
      final meta = data['mediaMetaData'] as Map<String, dynamic>;
      for (final key in const ['imageUrls', 'urls', 'mediaUrls']) {
        if (meta[key] is List) {
          for (final item in meta[key]) {
            final s = item.toString();
            if (s.startsWith('http') && !urls.contains(s)) urls.add(s);
          }
        }
      }
      for (final key in const ['imageUrl', 'audioUrl', 'videoUrl', 'fileUrl', 'url']) {
        final val = meta[key]?.toString();
        if (val != null && val.startsWith('http') && !urls.contains(val)) urls.add(val);
      }
    }

    final content = (data['content'] ?? '').toString();
    if (content.startsWith('http') && data['type'] != 'text' && !urls.contains(content)) {
      urls.add(content);
    }

    return urls;
  }

  Future<void> _deleteFirebaseStorageFilesSafe(List<String> urls) async {
    for (final url in urls) {
      if (url.isEmpty || !url.startsWith('http')) continue;
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> _fetchVerifiedTeacherMetadata(
      String teacherId, String fallbackName) async {
    bool isVerified = false;
    bool hasGoldenBadge = false;
    String name = fallbackName;
    String profilePic = '';
    String credentials = '';
    double rating = 0.0;

    final teacherDoc =
        await _firestore.collection('teachers').doc(teacherId).get();
    if (teacherDoc.exists && teacherDoc.data() != null) {
      final data = teacherDoc.data()!;
      name = (data['name'] ?? data['fullName'] ?? fallbackName).toString();
      profilePic =
          (data['profileUrl'] ?? data['profileImageUrl'] ?? '').toString();
      isVerified =
          (data['isVerified'] == true) || (data['status'] == 'approved');
      credentials = (data['qualification'] ??
              data['credentials'] ??
              data['tuitionName'] ??
              '')
          .toString();
      if (data['rating'] is num) {
        rating = (data['rating'] as num).toDouble();
      }
      if (data['hasGoldenBadge'] == true) {
        hasGoldenBadge = true;
      } else if (data['createdAt'] is Timestamp && isVerified) {
        final createdDate = (data['createdAt'] as Timestamp).toDate();
        final daysOnPlatform = DateTime.now().difference(createdDate).inDays;
        if (daysOnPlatform >= 1095) {
          hasGoldenBadge = true;
        }
      }
    } else {
      final userDoc = await _firestore.collection('users').doc(teacherId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final uData = userDoc.data()!;
        final role = (uData['role'] ?? uData['type'] ?? '').toString();
        if (role != 'teacher') {
          throw Exception('Only eligible teacher accounts can create groups.');
        }
        name = (uData['name'] ?? uData['fullName'] ?? fallbackName).toString();
        profilePic =
            (uData['profileUrl'] ?? uData['photoUrl'] ?? '').toString();
      }
    }

    return {
      'teacherName': name,
      'teacherProfilePic': profilePic,
      'isTeacherVerified': isVerified,
      'hasGoldenBadge': hasGoldenBadge,
      'teacherCredentials': credentials,
      'teacherRating': rating,
    };
  }

  Future<String> createGroup({
    required String name,
    required String createdBy,
    required String imageUrl,
    required String teacherName,
    String description = '',
    String batchName = '',
    String className = '',
    String subjectName = '',
    String courseName = '',
    String academicYear = '',
    String groupRules = '',
    String welcomeMessage = '',
    List<String> invitedStudentIds = const [],
  }) async {
    final teacherMeta =
        await _fetchVerifiedTeacherMetadata(createdBy, teacherName);

    final docRef = _firestore.collection('groups').doc();
    final now = Timestamp.now();
    final String defaultWelcome = welcomeMessage.trim().isNotEmpty
        ? welcomeMessage.trim()
        : 'Welcome to $name! Please follow the group rules.';

    final group = GroupModel(
      id: docRef.id,
      name: name.trim(),
      createdBy: createdBy,
      imageUrl: imageUrl,
      members: [createdBy],
      createdAt: now,
      description: description.trim(),
      batchName: batchName.trim(),
      className: className.trim(),
      subjectName: subjectName.trim(),
      courseName: courseName.trim(),
      academicYear: academicYear.trim(),
      groupRules: groupRules.trim(),
      welcomeMessage: defaultWelcome,
      teacherName: teacherMeta['teacherName'] as String,
      teacherProfilePic: teacherMeta['teacherProfilePic'] as String,
      isTeacherVerified: teacherMeta['isTeacherVerified'] as bool,
      hasGoldenBadge: teacherMeta['hasGoldenBadge'] as bool,
      teacherCredentials: teacherMeta['teacherCredentials'] as String,
      teacherRating: teacherMeta['teacherRating'] as double,
      onlyAdminCanPost: false,
      mutedStudents: const [],
      isDismissed: false,
      lastMessage: 'Group Created',
      lastMessageTime: now,
      lastSenderId: createdBy,
    );

    final WriteBatch batch = _firestore.batch();
    batch.set(docRef, group.toMap());

    final welcomeMsgRef = docRef.collection('messages').doc();
    final List<String> initialPendingFor = invitedStudentIds
        .where((uid) => uid.trim().isNotEmpty && uid != createdBy)
        .toList();

    final Map<String, dynamic> welcomeData = {
      'messageId': welcomeMsgRef.id,
      'senderId': createdBy,
      'receiverId': docRef.id,
      'content': defaultWelcome,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'status': 'sent',
      'senderRole': 'teacher',
      'senderName': teacherMeta['teacherName'],
      'senderProfilePic': teacherMeta['teacherProfilePic'],
      'isSenderVerified': teacherMeta['isTeacherVerified'],
      'hasSenderGoldenBadge': teacherMeta['hasGoldenBadge'],
      'messageCategory': 'announcement',
      'isPinned': true,
      'isDeletedForEveryone': false,
      'deletedForUsers': <String>[],
      'starredBy': <String>[],
      'reactions': <String, dynamic>{},
      'pendingFor': initialPendingFor,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
    };

    batch.set(welcomeMsgRef, welcomeData);

    final localWelcomeMsg = MessageModel(
      messageId: welcomeMsgRef.id,
      senderId: createdBy,
      receiverId: docRef.id,
      content: defaultWelcome,
      type: 'text',
      timestamp: DateTime.now(),
      status: 'sent',
      isDeletedForEveryone: false,
      deletedForUsers: const <String>[],
      starredBy: const <String>[],
      reactions: const <String, String>{},
      senderRole: 'teacher',
      senderName: teacherMeta['teacherName'],
      senderProfilePic: teacherMeta['teacherProfilePic'],
      isSenderVerified: teacherMeta['isTeacherVerified'],
      hasSenderGoldenBadge: teacherMeta['hasGoldenBadge'],
      messageCategory: 'announcement',
      isPinned: true,
    );
    await _localStorage.saveOutgoingMessageWithPermanentFiles(localWelcomeMsg, docRef.id);

    for (final studentId in invitedStudentIds) {
      if (studentId.trim().isEmpty || studentId == createdBy) continue;

      final inviteDocRef = _firestore.collection('invitations').doc();
      batch.set(inviteDocRef, {
        'id': inviteDocRef.id,
        'groupId': docRef.id,
        'groupName': name.trim(),
        'invitedUserId': studentId,
        'invitedByUserId': createdBy,
        'status': 'pending',
        'timestamp': now,
      });

      final userInviteRef = _firestore
          .collection('users')
          .doc(studentId)
          .collection('group_invites')
          .doc(docRef.id);
      batch.set(userInviteRef, {
        'groupId': docRef.id,
        'groupName': name.trim(),
        'invitedBy': createdBy,
        'teacherName': teacherMeta['teacherName'],
        'status': 'pending',
        'sentAt': FieldValue.serverTimestamp(),
      });

      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'notificationId': notifRef.id,
        'senderId': createdBy,
        'receiverId': studentId,
        'groupId': docRef.id,
        'title': 'New Group Invitation',
        'body':
            '${teacherMeta['teacherName']} invited you to join ${name.trim()}',
        'type': 'group_invite',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    }

    await batch.commit();
    return docRef.id;
  }

  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String message,
    required String type,
    String? senderName,
    String? senderRole,
    String? replyToMessageId,
    String? replyToText,
    Map<String, dynamic>? mediaMetaData,
    String messageCategory = 'general',
    Map<String, dynamic>? pollData,
    Map<String, dynamic>? quizData,
    Map<String, dynamic>? linkPreviewData,
    bool isForwarded = false,
    bool isScheduled = false,
    DateTime? scheduledAt,
    String? clientMessageId,
    String? caption,
    List<String>? mediaUrls,
  }) async {
    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupDoc = await groupRef.get();
    if (!groupDoc.exists || groupDoc.data() == null) return;
    final groupData = groupDoc.data()!;

    final messageRef = groupRef.collection('messages').doc();

    final Map<String, dynamic> messageData = {
      'messageId': messageRef.id,
      'groupId': groupId,
      'senderId': senderId,
      'senderName': senderName ?? '',
      'senderRole': senderRole ?? '',
      'content': message,
      'timestamp': isScheduled && scheduledAt != null
          ? Timestamp.fromDate(scheduledAt)
          : FieldValue.serverTimestamp(),
      'type': type,
      'status': 'sent',
      'isDeletedForEveryone': false,
      'deletedForUsers': <String>[],
      'starredBy': <String>[],
      'reactions': <String, dynamic>{},
      'messageCategory': messageCategory,
      'isPinned': false,
      'isForwarded': isForwarded,
      'deliveredTo': [senderId],
      'readBy': [senderId],
      'isScheduled': isScheduled,
      'scheduledAt':
          scheduledAt != null ? Timestamp.fromDate(scheduledAt) : null,
      'clientMessageId': clientMessageId,
    };

    if (caption != null && caption.trim().isNotEmpty) {
      messageData['caption'] = caption.trim();
    }
    if (mediaUrls != null && mediaUrls.isNotEmpty) {
      messageData['mediaUrls'] = mediaUrls;
    }
    if (replyToMessageId != null) {
      messageData['replyToMessageId'] = replyToMessageId;
    }
    if (replyToText != null) {
      messageData['replyText'] = replyToText;
      messageData['replyToText'] = replyToText;
    }
    if (mediaMetaData != null) messageData['mediaMetaData'] = mediaMetaData;
    if (pollData != null) messageData['pollData'] = pollData;
    if (quizData != null) messageData['quizData'] = quizData;
    if (linkPreviewData != null) {
      messageData['linkPreviewData'] = linkPreviewData;
    }

    final localMsg = MessageModel(
      messageId: messageRef.id,
      groupId: groupId,
      senderId: senderId,
      receiverId: '',
      senderName: senderName,
      senderRole: senderRole,
      content: message,
      type: type,
      timestamp: DateTime.now(),
      status: 'sent',
      isDeletedForEveryone: false,
      deletedForUsers: const <String>[],
      starredBy: const <String>[],
      reactions: const <String, String>{},
      replyToMessageId: replyToMessageId,
      replyText: replyToText,
      mediaMetaData: mediaMetaData,
      mediaUrl: (type == 'image' ||
              type == 'video' ||
              type == 'audio' ||
              type == 'document' ||
              type == 'album')
          ? message
          : null,
      mediaUrls: mediaUrls,
      caption: caption?.trim(),
      messageCategory: messageCategory,
      isPinned: false,
      pollData: pollData,
      quizData: quizData,
      clientMessageId: clientMessageId,
    );

    await _localStorage.saveOutgoingMessageWithPermanentFiles(
        localMsg, groupId);

    final batch = _firestore.batch();
    batch.set(messageRef, messageData);

    String previewText = message;
    if (type == 'image') previewText = '📷 Photo';
    if (type == 'video') previewText = '🎥 Video';
    if (type == 'audio') previewText = '🎵 Audio';
    if (type == 'document') previewText = '📄 Document';
    if (caption != null && caption.trim().isNotEmpty) {
      previewText = '$previewText: ${caption.trim()}';
    }

    final members = List<String>.from(groupData['members'] ?? []);
    final Map<String, dynamic> unreadUpdates = {};
    for (final member in members) {
      if (member != senderId) {
        unreadUpdates['unreadCounts.$member'] = FieldValue.increment(1);
      }
    }

    final Map<String, dynamic> groupUpdateData = {
      'lastMessage': previewText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
      'lastSenderName': senderName ?? '',
      ...unreadUpdates,
    };

    batch.update(groupRef, groupUpdateData);
    await batch.commit();
  }

  Future<void> acknowledgeGroupMessageDelivery({
    required String groupId,
    required String messageId,
    required String userId,
  }) async {
    if (groupId.trim().isEmpty || messageId.trim().isEmpty || userId.trim().isEmpty) return;

    final msgRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId);

    try {
      List<String> filesToDelete = <String>[];
      bool shouldDeleteDoc = false;

      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(msgRef);
        if (!snap.exists || snap.data() == null) return;

        final data = snap.data()!;
        final List<dynamic> rawPending = (data['pendingFor'] as List<dynamic>?) ?? <dynamic>[];
        final List<String> pending = rawPending.map((e) => e.toString()).toList();

        if (!pending.contains(userId)) return;

        pending.remove(userId);

        if (pending.isEmpty) {
          shouldDeleteDoc = true;
          filesToDelete = _extractMediaUrlsFromData(data);
          transaction.delete(msgRef);
        } else {
          transaction.update(msgRef, {'pendingFor': pending});
        }
      });

      if (shouldDeleteDoc && filesToDelete.isNotEmpty) {
        await _deleteFirebaseStorageFilesSafe(filesToDelete);
      }
    } catch (_) {}
  }

  Future<void> sendInvitation({
    required String groupId,
    required String groupName,
    required String invitedUserId,
    required String invitedByUserId,
  }) async {
    final isAdmin = await _verifySingleAdmin(groupId, invitedByUserId);
    if (!isAdmin) {
      throw Exception('Only the group teacher can invite students.');
    }

    final WriteBatch batch = _firestore.batch();

    final groupRef = _firestore.collection('groups').doc(groupId);
    batch.update(groupRef, {
      'removedStudents': FieldValue.arrayRemove([invitedUserId]),
      'pendingRemovalNotices': FieldValue.arrayRemove([invitedUserId]),
    });

    final docRef = _firestore.collection('invitations').doc();
    final invitation = InvitationModel(
      id: docRef.id,
      groupId: groupId,
      groupName: groupName,
      invitedUserId: invitedUserId,
      invitedByUserId: invitedByUserId,
      status: 'pending',
      timestamp: DateTime.now(),
    );
    batch.set(docRef, invitation.toMap());

    final userInviteRef = _firestore
        .collection('users')
        .doc(invitedUserId)
        .collection('group_invites')
        .doc(groupId);
    batch.set(userInviteRef, {
      'groupId': groupId,
      'groupName': groupName,
      'invitedBy': invitedByUserId,
      'status': 'pending',
      'sentAt': FieldValue.serverTimestamp(),
    });

    final notifRef = _firestore.collection('notifications').doc();
    batch.set(notifRef, {
      'notificationId': notifRef.id,
      'senderId': invitedByUserId,
      'receiverId': invitedUserId,
      'groupId': groupId,
      'title': 'Group Invitation',
      'body': 'You have been invited to join $groupName',
      'type': 'group_invite',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    await batch.commit();
  }

  Future<void> respondToInvitation(
    String invitationId,
    String groupId,
    String userId,
    bool accept,
  ) async {
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists || groupDoc.data() == null) {
      throw Exception('Group no longer exists.');
    }

    final groupModel = GroupModel.fromMap(groupDoc.data()!, groupDoc.id);
    if (groupModel.isDismissed) {
      throw Exception('This group has been dismissed by the teacher.');
    }

    final status = accept ? 'accepted' : 'rejected';
    final WriteBatch batch = _firestore.batch();

    if (invitationId.isNotEmpty) {
      final rootInviteRef =
          _firestore.collection('invitations').doc(invitationId);
      final rootInviteSnap = await rootInviteRef.get();
      if (rootInviteSnap.exists) {
        batch.update(rootInviteRef, {'status': status});
      }
    }

    final userInviteRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('group_invites')
        .doc(groupId);
    final userInviteSnap = await userInviteRef.get();
    if (userInviteSnap.exists) {
      batch.delete(userInviteRef);
    }

    if (accept) {
      batch.update(_firestore.collection('groups').doc(groupId), {
        'members': FieldValue.arrayUnion([userId]),
        'removedStudents': FieldValue.arrayRemove([userId]),
        'pendingRemovalNotices': FieldValue.arrayRemove([userId]),
      });
    }

    await batch.commit();
  }

  Future<void> addStudentDirectlyByTeacher({
    required String groupId,
    required String teacherId,
    required String studentId,
  }) async {
    final isAdmin = await _verifySingleAdmin(groupId, teacherId);
    if (!isAdmin) {
      throw Exception('Only the group teacher can add students.');
    }

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists || groupDoc.data() == null) return;
    final group = GroupModel.fromMap(groupDoc.data()!, groupDoc.id);
    if (group.isDismissed) {
      throw Exception('Cannot add students to a dismissed group.');
    }

    final WriteBatch batch = _firestore.batch();
    final groupRef = _firestore.collection('groups').doc(groupId);

    batch.update(groupRef, {
      'members': FieldValue.arrayUnion([studentId]),
      'removedStudents': FieldValue.arrayRemove([studentId]),
      'pendingRemovalNotices': FieldValue.arrayRemove([studentId]),
    });

    final noticeRef = _firestore
        .collection('users')
        .doc(studentId)
        .collection('group_notices')
        .doc(groupId);
    batch.delete(noticeRef);

    final notifRef = _firestore.collection('notifications').doc();
    batch.set(notifRef, {
      'notificationId': notifRef.id,
      'senderId': teacherId,
      'receiverId': studentId,
      'groupId': groupId,
      'title': 'Added to Group',
      'body': 'Teacher added you to ${group.name}',
      'type': 'student_added',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    await batch.commit();
  }

  Future<void> removeStudentFromGroup({
    required String groupId,
    required String teacherId,
    required String studentId,
  }) async {
    final isAdmin = await _verifySingleAdmin(groupId, teacherId);
    if (!isAdmin) {
      throw Exception('Only the group teacher can remove students.');
    }
    if (studentId == teacherId) {
      throw Exception('Teacher cannot remove themselves from their own group.');
    }

    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupSnap = await groupRef.get();
    if (!groupSnap.exists || groupSnap.data() == null) return;

    final group = GroupModel.fromMap(groupSnap.data()!, groupSnap.id);

    final WriteBatch batch = _firestore.batch();

    batch.update(groupRef, {
      'members': FieldValue.arrayRemove([studentId]),
      'mutedStudents': FieldValue.arrayRemove([studentId]),
      'removedStudents': FieldValue.arrayUnion([studentId]),
      'pendingRemovalNotices': FieldValue.arrayUnion([studentId]),
    });

    final userNoticeRef = _firestore
        .collection('users')
        .doc(studentId)
        .collection('group_notices')
        .doc(groupId);
    batch.set(userNoticeRef, {
      'groupId': groupId,
      'groupName': group.name,
      'teacherId': teacherId,
      'teacherName': group.teacherName,
      'noticeType': 'removed',
      'message': 'You have been removed from this group by the teacher.',
      'acknowledged': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final notifRef = _firestore.collection('notifications').doc();
    batch.set(notifRef, {
      'notificationId': notifRef.id,
      'senderId': teacherId,
      'receiverId': studentId,
      'groupId': groupId,
      'title': group.name,
      'body': 'You have been removed from this group by the teacher.',
      'type': 'group_removed',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    await batch.commit();
  }

  Future<void> leaveGroup({
    required String groupId,
    required String studentId,
  }) async {
    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupSnap = await groupRef.get();
    if (!groupSnap.exists || groupSnap.data() == null) return;

    final group = GroupModel.fromMap(groupSnap.data()!, groupSnap.id);
    if (studentId == group.createdBy) {
      throw Exception(
          'Teacher admin cannot leave their own group. Use dismiss instead.');
    }

    final WriteBatch batch = _firestore.batch();

    batch.update(groupRef, {
      'members': FieldValue.arrayRemove([studentId]),
      'mutedStudents': FieldValue.arrayRemove([studentId]),
      'removedStudents': FieldValue.arrayRemove([studentId]),
      'pendingRemovalNotices': FieldValue.arrayRemove([studentId]),
    });

    final userNoticeRef = _firestore
        .collection('users')
        .doc(studentId)
        .collection('group_notices')
        .doc(groupId);
    batch.delete(userNoticeRef);

    await batch.commit();
    await _localStorage.clearRoomLocally(groupId);
  }

  Future<void> acknowledgeStudentRemoval({
    required String groupId,
    required String studentId,
  }) async {
    try {
      final groupRef = _firestore.collection('groups').doc(groupId);
      await groupRef.update({
        'pendingRemovalNotices': FieldValue.arrayRemove([studentId]),
      });
    } catch (_) {}

    try {
      final userNoticeRef = _firestore
          .collection('users')
          .doc(studentId)
          .collection('group_notices')
          .doc(groupId);
      await userNoticeRef.delete();
    } catch (_) {}
  }

  Future<void> setStudentMuteStatus({
    required String groupId,
    required String teacherId,
    required String studentId,
    required bool mute,
  }) async {
    final isAdmin = await _verifySingleAdmin(groupId, teacherId);
    if (!isAdmin) {
      throw Exception('Only the group teacher can mute or unmute students.');
    }
    if (studentId == teacherId) return;

    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupSnap = await groupRef.get();
    if (!groupSnap.exists || groupSnap.data() == null) return;
    final group = GroupModel.fromMap(groupSnap.data()!, groupSnap.id);

    final WriteBatch batch = _firestore.batch();

    batch.update(groupRef, {
      'mutedStudents': mute
          ? FieldValue.arrayUnion([studentId])
          : FieldValue.arrayRemove([studentId]),
    });

    final notifRef = _firestore.collection('notifications').doc();
    batch.set(notifRef, {
      'notificationId': notifRef.id,
      'senderId': teacherId,
      'receiverId': studentId,
      'groupId': groupId,
      'title': group.name,
      'body': mute
          ? 'You have been muted by the teacher in ${group.name}.'
          : 'You have been unmuted by the teacher in ${group.name}.',
      'type': mute ? 'student_muted' : 'student_unmuted',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    await batch.commit();
  }

  Future<void> muteStudent({
    required String groupId,
    required String teacherId,
    required String studentId,
  }) async {
    await setStudentMuteStatus(
      groupId: groupId,
      teacherId: teacherId,
      studentId: studentId,
      mute: true,
    );
  }

  Future<void> unmuteStudent({
    required String groupId,
    required String teacherId,
    required String studentId,
  }) async {
    await setStudentMuteStatus(
      groupId: groupId,
      teacherId: teacherId,
      studentId: studentId,
      mute: false,
    );
  }

  Future<void> dismissGroup({
    required String groupId,
    required String teacherId,
  }) async {
    final isAdmin = await _verifySingleAdmin(groupId, teacherId);
    if (!isAdmin) {
      throw Exception('Only the group teacher can dismiss this group.');
    }

    final groupRef = _firestore.collection('groups').doc(groupId);
    final groupSnap = await groupRef.get();
    if (!groupSnap.exists || groupSnap.data() == null) return;

    final group = GroupModel.fromMap(groupSnap.data()!, groupSnap.id);
    if (group.isDismissed) return;

    final List<String> studentMembers =
        group.members.where((uid) => uid != teacherId).toList();

    final WriteBatch batch = _firestore.batch();

    batch.update(groupRef, {
      'isDismissed': true,
      'dismissedAt': FieldValue.serverTimestamp(),
      'unacknowledgedDismissMembers': studentMembers,
      'onlyAdminCanPost': true,
      'lastMessage': 'This group has been dismissed by the teacher.',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    for (final studentId in studentMembers) {
      final userNoticeRef = _firestore
          .collection('users')
          .doc(studentId)
          .collection('group_notices')
          .doc(groupId);
      batch.set(userNoticeRef, {
        'groupId': groupId,
        'groupName': group.name,
        'teacherId': teacherId,
        'teacherName': group.teacherName,
        'noticeType': 'dismissed',
        'message': 'This group has been dismissed by the teacher.',
        'acknowledged': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'notificationId': notifRef.id,
        'senderId': teacherId,
        'receiverId': studentId,
        'groupId': groupId,
        'title': group.name,
        'body': 'This group has been dismissed by the teacher.',
        'type': 'group_dismissed',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    }

    await batch.commit();
    await _cleanupGroupMessages(groupId);
    await _localStorage.clearRoomLocally(groupId);
  }

  Future<void> _cleanupGroupMessages(String groupId) async {
    const int batchSize = 200;
    while (true) {
      final messagesSnap = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .limit(batchSize)
          .get();

      if (messagesSnap.docs.isEmpty) break;

      final List<String> mediaUrlsToDelete = <String>[];
      final WriteBatch deleteBatch = _firestore.batch();
      for (final doc in messagesSnap.docs) {
        final data = doc.data();
        mediaUrlsToDelete.addAll(_extractMediaUrlsFromData(data));
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
      await _deleteFirebaseStorageFilesSafe(mediaUrlsToDelete);

      if (messagesSnap.docs.length < batchSize) break;
    }
  }

  Future<void> acknowledgeGroupDismissal({
    required String groupId,
    required String studentId,
  }) async {
    try {
      final groupRef = _firestore.collection('groups').doc(groupId);
      await groupRef.update({
        'unacknowledgedDismissMembers': FieldValue.arrayRemove([studentId]),
        'members': FieldValue.arrayRemove([studentId]),
      });
    } catch (_) {}

    try {
      final userNoticeRef = _firestore
          .collection('users')
          .doc(studentId)
          .collection('group_notices')
          .doc(groupId);
      await userNoticeRef.delete();
    } catch (_) {}
  }

  Future<void> setAdminOnlyPostingMode({
    required String groupId,
    required String teacherId,
    required bool onlyAdminCanPost,
  }) async {
    final isAdmin = await _verifySingleAdmin(groupId, teacherId);
    if (!isAdmin) {
      throw Exception('Only the group teacher can change posting mode.');
    }

    await _firestore.collection('groups').doc(groupId).update({
      'onlyAdminCanPost': onlyAdminCanPost,
    });
  }

  Future<void> updateGroupDetails({
    required String groupId,
    required String teacherId,
    String? name,
    String? imageUrl,
    String? description,
    String? batchName,
    String? className,
    String? subjectName,
    String? courseName,
    String? academicYear,
    String? groupRules,
    String? welcomeMessage,
    int? disappearingDurationHours,
  }) async {
    final isAdmin = await _verifySingleAdmin(groupId, teacherId);
    if (!isAdmin) {
      throw Exception('Only the group teacher can update group details.');
    }

    final Map<String, dynamic> updates = {};
    if (name != null && name.trim().isNotEmpty) {
      updates['name'] = name.trim();
      updates['groupName'] = name.trim();
    }
    if (imageUrl != null) {
      updates['imageUrl'] = imageUrl;
      updates['groupImageUrl'] = imageUrl;
    }
    if (description != null) updates['description'] = description.trim();
    if (batchName != null) updates['batchName'] = batchName.trim();
    if (className != null) updates['className'] = className.trim();
    if (subjectName != null) updates['subjectName'] = subjectName.trim();
    if (courseName != null) updates['courseName'] = courseName.trim();
    if (academicYear != null) updates['academicYear'] = academicYear.trim();
    if (groupRules != null) updates['groupRules'] = groupRules.trim();
    if (welcomeMessage != null) {
      updates['welcomeMessage'] = welcomeMessage.trim();
    }
    if (disappearingDurationHours != null) {
      updates['disappearingDurationHours'] = disappearingDurationHours;
    }

    if (updates.isNotEmpty) {
      await _firestore.collection('groups').doc(groupId).update(updates);
    }
  }

  Future<void> togglePinMessage({
    required String groupId,
    required String teacherId,
    required String messageId,
    required bool pin,
  }) async {
    final isAdmin = await _verifySingleAdmin(groupId, teacherId);
    if (!isAdmin) {
      throw Exception('Only the group teacher can pin or unpin messages.');
    }

    await _localStorage.togglePinLocally(
      messageId: messageId,
      chatRoomId: groupId,
      isPinned: pin,
    );

    final WriteBatch batch = _firestore.batch();
    final groupRef = _firestore.collection('groups').doc(groupId);
    final msgRef = groupRef.collection('messages').doc(messageId);

    batch.update(groupRef, {
      'pinnedMessageIds': pin
          ? FieldValue.arrayUnion([messageId])
          : FieldValue.arrayRemove([messageId]),
    });

    batch.update(msgRef, {'isPinned': pin});
    await batch.commit();
  }

  Future<void> toggleGroupNotificationMute({
    required String groupId,
    required String userId,
    required bool mute,
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
      'mutedByUsers': mute
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> toggleGroupArchive({
    required String groupId,
    required String userId,
    required bool archive,
  }) async {
    await _firestore.collection('groups').doc(groupId).update({
      'archivedByUsers': archive
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
    });
  }

  Future<Map<String, dynamic>> getGroupMembersWithPrivacy({
    required String groupId,
    required String viewerId,
  }) async {
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists || groupDoc.data() == null) {
      throw Exception('Group not found');
    }

    final group = GroupModel.fromMap(groupDoc.data()!, groupDoc.id);
    final bool isViewerTeacher = group.isSingleAdmin(viewerId);

    final Map<String, dynamic> teacherProfile = {
      'uid': group.createdBy,
      'name': group.teacherName.isNotEmpty ? group.teacherName : 'Teacher',
      'profilePic': group.teacherProfilePic,
      'isVerified': group.isTeacherVerified,
      'hasGoldenBadge': group.hasGoldenBadge,
      'credentials': group.teacherCredentials,
      'rating': group.teacherRating,
      'role': 'teacher',
    };

    if (!isViewerTeacher) {
      return {
        'isViewerTeacher': false,
        'teacher': teacherProfile,
        'studentCount': group.studentCount,
        'students': const [],
      };
    }

    final List<Map<String, dynamic>> studentsList = [];
    final List<String> studentIds =
        group.members.where((id) => id != group.createdBy).toList();

    for (final studentId in studentIds) {
      String studentName = 'Student';
      String studentPhoto = '';

      final studentDoc =
          await _firestore.collection('students').doc(studentId).get();
      if (studentDoc.exists && studentDoc.data() != null) {
        final sData = studentDoc.data()!;
        studentName =
            (sData['name'] ?? sData['fullName'] ?? 'Student').toString();
        studentPhoto = (sData['profileImageUrl'] ??
                sData['profileUrl'] ??
                sData['photoUrl'] ??
                '')
            .toString();
      } else {
        final userDoc =
            await _firestore.collection('users').doc(studentId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final uData = userDoc.data()!;
          studentName =
              (uData['name'] ?? uData['fullName'] ?? 'Student').toString();
          studentPhoto =
              (uData['photoUrl'] ?? uData['profileUrl'] ?? '').toString();
        }
      }

      studentsList.add({
        'uid': studentId,
        'name': studentName,
        'profilePic': studentPhoto,
        'isMuted': group.isStudentMuted(studentId),
        'role': 'student',
      });
    }

    return {
      'isViewerTeacher': true,
      'teacher': teacherProfile,
      'studentCount': studentIds.length,
      'students': studentsList,
    };
  }

  Future<void> voteOnPoll({
    required String groupId,
    required String messageId,
    required String userId,
    required int optionIndex,
  }) async {
    await _localStorage.updatePollVoteLocally(
      messageId: messageId,
      chatRoomId: groupId,
      userId: userId,
      optionIndex: optionIndex,
    );

    final msgRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(msgRef);
      if (!snap.exists || snap.data() == null) return;

      final data = snap.data()!;
      final Map<String, dynamic> pollData = data['pollData'] != null
          ? Map<String, dynamic>.from(data['pollData'] as Map)
          : {};
      final Map<String, dynamic> votes = pollData['votes'] != null
          ? Map<String, dynamic>.from(pollData['votes'] as Map)
          : {};

      votes[userId] = optionIndex;
      pollData['votes'] = votes;

      transaction.update(msgRef, {'pollData': pollData});
    });
  }

  Future<void> submitQuizAnswer({
    required String groupId,
    required String messageId,
    required String userId,
    required int selectedOptionIndex,
  }) async {
    await _localStorage.updateQuizAnswerLocally(
      messageId: messageId,
      chatRoomId: groupId,
      userId: userId,
      optionIndex: selectedOptionIndex,
    );

    final msgRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(msgRef);
      if (!snap.exists || snap.data() == null) return;

      final data = snap.data()!;
      final Map<String, dynamic> quizData = data['quizData'] != null
          ? Map<String, dynamic>.from(data['quizData'] as Map)
          : {};
      final Map<String, dynamic> submissions = quizData['submissions'] != null
          ? Map<String, dynamic>.from(quizData['submissions'] as Map)
          : {};

      if (submissions.containsKey(userId)) return;

      submissions[userId] = selectedOptionIndex;
      quizData['submissions'] = submissions;

      transaction.update(msgRef, {'quizData': quizData});
    });
  }

  Stream<GroupModel?> getGroupStream(String groupId) {
    return _firestore.collection('groups').doc(groupId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return GroupModel.fromMap(doc.data()!, doc.id);
    });
  }

  Stream<List<GroupModel>> getTeacherGroups(String teacherId) {
    return _firestore
        .collection('groups')
        .where('createdBy', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
            .where((group) => !group.isDismissed)
            .toList());
  }

  Stream<List<GroupModel>> getUserActiveGroupsStream(String userId) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final groups = snapshot.docs
          .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
          .where((group) =>
              !group.isDismissed && !group.isStudentRemoved(userId))
          .toList();

      groups.sort((a, b) {
        final aTime = a.lastMessageTime ?? a.createdAt;
        final bTime = b.lastMessageTime ?? b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return groups;
    });
  }

  Stream<List<Map<String, dynamic>>> getPendingGroupNoticesStream(
      String userId) {
    if (userId.trim().isEmpty) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('group_notices')
        .where('acknowledged', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['docId'] = doc.id;
              return data;
            }).toList());
  }

  Stream<List<InvitationModel>> getStudentInvitations(String userId) {
    return _firestore
        .collection('invitations')
        .where('invitedUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InvitationModel.fromMap(doc.id, doc.data()))
            .toList());
  }
}