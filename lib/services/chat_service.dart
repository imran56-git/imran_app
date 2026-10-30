import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';
import 'local_chat_storage_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalChatStorageService _localStorage = LocalChatStorageService();
  final Map<String, DateTime> _recentClientMessages = {};

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  Future?> getUserProfile(
      String userId, bool isTeacher) async {
    if (userId.trim().isEmpty) return null;
    try {
      final String primaryCollection = isTeacher ? 'teachers' : 'students';
      final String secondaryCollection = isTeacher ? 'students' : 'teachers';

      var doc =
          await _firestore.collection(primaryCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) return doc.data();

      doc = await _firestore.collection(secondaryCollection).doc(userId).get();
      if (doc.exists && doc.data() != null) return doc.data();

      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data();
    } catch (e) {
      _handleError('getUserProfile', e);
      return null;
    }
  }

  Stream<QuerySnapshot> getUserChatsStream(String userId) {
    if (userId.trim().isEmpty) {
      return const Stream.empty();
    }
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .handleError((error) {
      _handleError('getUserChatsStream', error);
    });
  }

  Stream<int> getTotalUnreadChatsCountStream(String userId) {
    if (userId.trim().isEmpty) return Stream.value(0);
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final List<dynamic> archivedBy =
            (data['archivedBy'] as List<dynamic>?) ?? const [];
        if (archivedBy.contains(userId)) continue;

        if (data.containsKey('unreadCount_$userId')) {
          total += (data['unreadCount_$userId'] as num?)?.toInt() ?? 0;
        } else if (data['unreadFor'] == userId) {
          total += (data['unreadCount'] as num?)?.toInt() ?? 0;
        }
      }
      return total;
    }).handleError((e) {
      _handleError('getTotalUnreadChatsCountStream', e);
    });
  }

  Stream<int> getTotalUnreadGroupsCountStream(String userId) {
    if (userId.trim().isEmpty) return Stream.value(0);
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final group = GroupModel.fromMap(doc.data(), doc.id);
        if (group.isDismissed || group.isStudentRemoved(userId)) continue;
        if (group.archivedByUsers.contains(userId)) continue;
        total += group.getUnreadCountForUser(userId);
      }
      return total;
    }).handleError((e) {
      _handleError('getTotalUnreadGroupsCountStream', e);
    });
  }

  Future<void> updateOnlineStatus(
      String userId, bool isOnline, bool isTeacher) async {
    if (userId.trim().isEmpty) return;
    try {
      final Map<String, dynamic> statusData = {
        'isOnline': isOnline,
        'status': isOnline ? 'Online' : 'Offline',
        'lastSeen': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .set(statusData, SetOptions(merge: true));
      await _firestore
          .collection('teachers')
          .doc(userId)
          .set(statusData, SetOptions(merge: true));
      await _firestore
          .collection('students')
          .doc(userId)
          .set(statusData, SetOptions(merge: true));
    } catch (e) {
      _handleError('updateOnlineStatus', e);
    }
  }

  Future<void> updateTypingStatus(
      String chatId, String userId, bool isTyping) async {
    if (chatId.trim().isEmpty || userId.trim().isEmpty) return;
    try {
      await _firestore.collection('typing').doc(chatId).set({
        userId: isTyping,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _handleError('updateTypingStatus', e);
    }
  }

  Stream<bool> getTypingStatusStream(String chatOrGroupId, String otherUserId) {
    if (chatOrGroupId.trim().isEmpty || otherUserId.trim().isEmpty) {
      return Stream.value(false);
    }
    return _firestore
        .collection('typing')
        .doc(chatOrGroupId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return false;
      return doc.data()![otherUserId] == true;
    }).handleError((e) {
      _handleError('getTypingStatusStream', e);
    });
  }

  Stream> getUserStatusStream(
      String userId, bool isTeacher) {
    if (userId.trim().isEmpty) {
      return Stream.value(
          {'status': 'Offline', 'lastSeen': null, 'isOnline': false});
    }

    final String primaryCollection = isTeacher ? 'teachers' : 'students';

    return _firestore
        .collection(primaryCollection)
        .doc(userId)
        .snapshots()
        .asyncMap((doc) async {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final map = Map<String, dynamic>.from(data);
        map['status'] =
            data['status'] ?? (data['isOnline'] == true ? 'Online' : 'Offline');
        map['isOnline'] = data['isOnline'] == true;
        map['lastSeen'] = data['lastSeen'] as Timestamp?;
        map['fullName'] = data['fullName'] ??
            data['name'] ??
            data['displayName'] ??
            data['teacherName'] ??
            data['studentName'];
        map['profileImageUrl'] = data['profileImageUrl'] ??
            data['profilePic'] ??
            data['profileUrl'] ??
            '';
        map['isVerified'] = data['isVerified'] == true ||
            data['status'] == 'approved' ||
            data['verificationStatus'] == 'verified';
        return map;
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final map = Map<String, dynamic>.from(data);
        map['status'] =
            data['status'] ?? (data['isOnline'] == true ? 'Online' : 'Offline');
        map['isOnline'] = data['isOnline'] == true;
        map['lastSeen'] = data['lastSeen'] as Timestamp?;
        map['fullName'] = data['fullName'] ??
            data['name'] ??
            data['displayName'] ??
            data['teacherName'] ??
            data['studentName'];
        map['profileImageUrl'] = data['profileImageUrl'] ??
            data['profilePic'] ??
            data['profileUrl'] ??
            '';
        map['isVerified'] = data['isVerified'] == true ||
            data['status'] == 'approved' ||
            data['verificationStatus'] == 'verified';
        return map;
      }

      final String altCollection = isTeacher ? 'students' : 'teachers';
      final altDoc =
          await _firestore.collection(altCollection).doc(userId).get();
      if (altDoc.exists && altDoc.data() != null) {
        final data = altDoc.data()!;
        final map = Map<String, dynamic>.from(data);
        map['status'] =
            data['status'] ?? (data['isOnline'] == true ? 'Online' : 'Offline');
        map['isOnline'] = data['isOnline'] == true;
        map['lastSeen'] = data['lastSeen'] as Timestamp?;
        map['fullName'] = data['fullName'] ??
            data['name'] ??
            data['displayName'] ??
            data['teacherName'] ??
            data['studentName'];
        map['profileImageUrl'] = data['profileImageUrl'] ??
            data['profilePic'] ??
            data['profileUrl'] ??
            '';
        map['isVerified'] = data['isVerified'] == true ||
            data['status'] == 'approved' ||
            data['verificationStatus'] == 'verified';
        return map;
      }

      return {'status': 'Offline', 'lastSeen': null, 'isOnline': false};
    }).handleError((error) {
      _handleError('getUserStatusStream', error);
    });
  }

  String getChatRoomId(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> createOrInitializeChat({
    required String teacherId,
    required String studentId,
    required String teacherName,
    required String studentName,
    required String teacherImage,
    required String studentImage,
  }) async {
    try {
      final String chatId = getChatRoomId(teacherId, studentId);
      final chatRef = _firestore.collection('chats').doc(chatId);
      final doc = await chatRef.get();

      Map<String, dynamic> updateData = {
        'chatId': chatId,
        'teacherId': teacherId,
        'studentId': studentId,
        'participants': [teacherId, studentId]..sort(),
        'isGroup': false,
      };

      if (teacherName.isNotEmpty &&
          teacherName != 'Me' &&
          teacherName != 'User') {
        updateData['teacherName'] = teacherName;
      }
      if (studentName.isNotEmpty &&
          studentName != 'Me' &&
          studentName != 'User') {
        updateData['studentName'] = studentName;
      }
      if (teacherImage.isNotEmpty) updateData['teacherImage'] = teacherImage;
      if (studentImage.isNotEmpty) updateData['studentImage'] = studentImage;

      if (!doc.exists) {
        updateData['lastMessage'] = 'Chat initialized';
        updateData['lastMessageContent'] = 'Chat initialized';
        updateData['lastMessageTime'] = FieldValue.serverTimestamp();
        updateData['unreadCount'] = 0;
        updateData['unreadFor'] = '';
        updateData['pinnedBy'] = [];
        updateData['mutedBy'] = [];
        updateData['archivedBy'] = [];
        updateData['blockedBy'] = [];
        updateData['createdAt'] = FieldValue.serverTimestamp();
        await chatRef.set(updateData);
      } else {
        await chatRef.set(updateData, SetOptions(merge: true));
      }
    } catch (e) {
      _handleError('createOrInitializeChat', e);
    }
  }

  bool _isDuplicateSubmission(String dedupeKey) {
    final now = DateTime.now();
    _recentClientMessages.removeWhere(
        (_, timestamp) => now.difference(timestamp).inSeconds > 5);
    if (_recentClientMessages.containsKey(dedupeKey)) {
      return true;
    }
    _recentClientMessages[dedupeKey] = now;
    return false;
  }

  String _buildMessagePreviewText(String message, String type,
      {String category = 'general'}) {
    if (category == 'poll' || type == 'poll') return '📊 Poll: $message';
    if (category == 'quiz' || type == 'quiz') return '📝 Quiz: $message';
    if (category == 'homework') return '📚 Homework: $message';
    if (category == 'announcement') return '📢 Announcement: $message';
    if (category == 'study_material') return '📖 Study Material: $message';
    if (type == 'image') return '📷 Photo';
    if (type == 'video') return '🎥 Video';
    if (type == 'audio' || type == 'voice') return '🎵 Voice message';
    if (type == 'document') return '📄 Document';
    if (type == 'location') return '📍 Location';
    return message;
  }

  Future<String?> _downloadAndCacheMediaLocally(
      String url, String messageId) async {
    if (!url.startsWith('http')) return null;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final dbPath = await getDatabasesPath();
        final mediaDir = Directory(p.join(dbPath, 'fybtt_media'));
        if (!await mediaDir.exists()) {
          await mediaDir.create(recursive: true);
        }
        final file = File(p.join(mediaDir.path, '${messageId}_media.bin'));
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
    } catch (_) {}
    return null;
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String message,
    required String type,
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
  }) async {
    if (receiverId == 'group') {
      await sendGroupMessage(
        groupId: chatId,
        senderId: senderId,
        message: message,
        type: type,
        replyToMessageId: replyToMessageId,
        replyToText: replyToText,
        mediaMetaData: mediaMetaData,
        messageCategory: messageCategory,
        pollData: pollData,
        quizData: quizData,
        linkPreviewData: linkPreviewData,
        isForwarded: isForwarded,
        isScheduled: isScheduled,
        scheduledAt: scheduledAt,
        clientMessageId: clientMessageId,
      );
      return;
    }

    try {
      final String dedupeKey =
          clientMessageId ?? '${senderId}_${receiverId}_${type}_$message';
      if (_isDuplicateSubmission(dedupeKey)) return;

      final String correctChatId = getChatRoomId(senderId, receiverId);
      final chatRef = _firestore.collection('chats').doc(correctChatId);
      final chatDoc = await chatRef.get();

      int disappearingHours = 0;
      if (chatDoc.exists && chatDoc.data() != null) {
        final chatData = chatDoc.data()!;
        final List<dynamic> blockedBy =
            (chatData['blockedBy'] as List<dynamic>?) ?? const [];
        if (blockedBy.isNotEmpty) {
          throw Exception('Cannot send message. This conversation is blocked.');
        }
        disappearingHours =
            (chatData['disappearingDurationHours'] as num?)?.toInt() ?? 0;
      }

      DateTime? expiresAt;
      if (disappearingHours > 0) {
        expiresAt = DateTime.now().add(Duration(hours: disappearingHours));
      }

      final messageRef = chatRef.collection('messages').doc();

      final Map<String, dynamic> messageData = {
        'messageId': messageRef.id,
        'senderId': senderId,
        'receiverId': receiverId,
        'content': message,
        'timestamp': isScheduled && scheduledAt != null
            ? Timestamp.fromDate(scheduledAt)
            : FieldValue.serverTimestamp(),
        'type': type,
        'status': 'sent',
        'isDeletedForEveryone': false,
        'deletedForUsers': [],
        'starredBy': [],
        'reactions': {},
        'messageCategory': messageCategory,
        'isPinned': false,
        'isForwarded': isForwarded,
        'deliveredTo': [senderId],
        'readBy': [senderId],
        'isScheduled': isScheduled,
        'scheduledAt':
            scheduledAt != null ? Timestamp.fromDate(scheduledAt) : null,
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'clientMessageId': clientMessageId,
      };

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
        senderId: senderId,
        receiverId: receiverId,
        content: message,
        type: type,
        timestamp: DateTime.now(),
        status: 'sent',
        isDeletedForEveryone: false,
        deletedForUsers: const [],
        starredBy: const [],
        reactions: const {},
        replyToMessageId: replyToMessageId,
        replyText: replyToText,
        mediaMetaData: mediaMetaData,
        mediaUrl: (type == 'image' ||
                type == 'video' ||
                type == 'audio' ||
                type == 'document')
            ? message
            : null,
        messageCategory: messageCategory,
        isPinned: false,
        pollData: pollData,
        quizData: quizData,
        clientMessageId: clientMessageId,
      );
      await _localStorage.saveMessage(localMsg, correctChatId);

      final batch = _firestore.batch();
      batch.set(messageRef, messageData);

      final String previewText =
          _buildMessagePreviewText(message, type, category: messageCategory);

      int currentUnread = 0;
      if (chatDoc.exists && chatDoc.data() != null) {
        final data = chatDoc.data()!;
        if (data.containsKey('unreadCount_$receiverId')) {
          currentUnread = (data['unreadCount_$receiverId'] ?? 0) as int;
        } else if (data['unreadFor'] == receiverId) {
          currentUnread = (data['unreadCount'] ?? 0) as int;
        }
      }

      final List<String> sortedParticipants = [senderId, receiverId]..sort();

      batch.set(
          chatRef,
          {
            'chatId': correctChatId,
            'lastMessage': previewText,
            'lastMessageContent': previewText,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastSenderId': senderId,
            'unreadCount': currentUnread + 1,
            'unreadFor': receiverId,
            'unreadCount_$receiverId': currentUnread + 1,
            'participants': sortedParticipants,
            'deletedBy': FieldValue.arrayRemove([senderId, receiverId]),
          },
          SetOptions(merge: true));

      final notificationRef = _firestore.collection('notifications').doc();
      batch.set(notificationRef, {
        'notificationId': notificationRef.id,
        'senderId': senderId,
        'receiverId': receiverId,
        'chatId': correctChatId,
        'title': 'New Message',
        'body': previewText,
        'type': 'chat',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      await batch.commit();
    } catch (e) {
      _handleError('sendMessage', e);
      throw Exception('Failed to send message: $e');
    }
  }

  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String message,
    required String type,
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
  }) async {
    try {
      final String dedupeKey =
          clientMessageId ?? '${senderId}_${groupId}_${type}_$message';
      if (_isDuplicateSubmission(dedupeKey)) return;

      final groupRef = _firestore.collection('groups').doc(groupId);
      final groupSnap = await groupRef.get();
      if (!groupSnap.exists || groupSnap.data() == null) {
        throw Exception('Group does not exist.');
      }

      final group = GroupModel.fromMap(groupSnap.data()!, groupSnap.id);

      if (group.isDismissed) {
        throw Exception('This group has been dismissed by the teacher.');
      }
      if (group.isStudentRemoved(senderId) ||
          !group.members.contains(senderId)) {
        throw Exception('You are not an active member of this group.');
      }

      final bool isTeacherSender = group.isSingleAdmin(senderId);

      if (!isTeacherSender && group.isStudentMuted(senderId)) {
        throw Exception('Muted by teacher. You cannot send messages.');
      }
      if (!isTeacherSender && group.onlyAdminCanPost) {
        throw Exception('Only the teacher can send messages in this group.');
      }

      String senderName = isTeacherSender ? group.teacherName : 'Student';
      String senderProfilePic = isTeacherSender ? group.teacherProfilePic : '';

      if (!isTeacherSender) {
        final sDoc =
            await _firestore.collection('students').doc(senderId).get();
        if (sDoc.exists && sDoc.data() != null) {
          final sData = sDoc.data()!;
          senderName =
              (sData['name'] ?? sData['fullName'] ?? 'Student').toString();
          senderProfilePic = (sData['profileImageUrl'] ??
                  sData['profileUrl'] ??
                  sData['photoUrl'] ??
                  '')
              .toString();
        } else {
          final uDoc = await _firestore.collection('users').doc(senderId).get();
          if (uDoc.exists && uDoc.data() != null) {
            final uData = uDoc.data()!;
            senderName =
                (uData['name'] ?? uData['fullName'] ?? 'Student').toString();
            senderProfilePic =
                (uData['photoUrl'] ?? uData['profileUrl'] ?? '').toString();
          }
        }
      }

      DateTime? expiresAt;
      if (group.disappearingDurationHours > 0) {
        expiresAt = DateTime.now()
            .add(Duration(hours: group.disappearingDurationHours));
      }

      final messageRef = groupRef.collection('messages').doc();

      final Map<String, dynamic> messageData = {
        'messageId': messageRef.id,
        'senderId': senderId,
        'receiverId': groupId,
        'content': message,
        'type': type,
        'status': 'sent',
        'timestamp': isScheduled && scheduledAt != null
            ? Timestamp.fromDate(scheduledAt)
            : FieldValue.serverTimestamp(),
        'isRead': false,
        'isDeletedForEveryone': false,
        'deletedForUsers': [],
        'starredBy': [],
        'reactions': {},
        'replyToMessageId': replyToMessageId,
        'replyText': replyToText,
        'replyToText': replyToText,
        'mediaMetaData': mediaMetaData,
        'senderRole': isTeacherSender ? 'teacher' : 'student',
        'senderName': senderName,
        'senderProfilePic': senderProfilePic,
        'isSenderVerified': isTeacherSender ? group.isTeacherVerified : false,
        'hasSenderGoldenBadge': isTeacherSender ? group.hasGoldenBadge : false,
        'messageCategory': messageCategory,
        'isPinned': false,
        'isForwarded': isForwarded,
        'deliveredTo': [senderId],
        'readBy': [senderId],
        'pollData': pollData,
        'quizData': quizData,
        'linkPreviewData': linkPreviewData,
        'isScheduled': isScheduled,
        'scheduledAt':
            scheduledAt != null ? Timestamp.fromDate(scheduledAt) : null,
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'replyThreadCount': 0,
        'parentThreadMessageId': replyToMessageId,
        'clientMessageId': clientMessageId,
        'reportedBy': [],
      };

      final localGroupMsg = MessageModel(
        messageId: messageRef.id,
        senderId: senderId,
        receiverId: groupId,
        content: message,
        type: type,
        timestamp: DateTime.now(),
        status: 'sent',
        isDeletedForEveryone: false,
        deletedForUsers: const [],
        starredBy: const [],
        reactions: const {},
        replyToMessageId: replyToMessageId,
        replyText: replyToText,
        mediaMetaData: mediaMetaData,
        mediaUrl: (type == 'image' ||
                type == 'video' ||
                type == 'audio' ||
                type == 'document')
            ? message
            : null,
        senderRole: isTeacherSender ? 'teacher' : 'student',
        senderName: senderName,
        senderProfilePic: senderProfilePic,
        isSenderVerified: isTeacherSender ? group.isTeacherVerified : false,
        hasSenderGoldenBadge: isTeacherSender ? group.hasGoldenBadge : false,
        messageCategory: messageCategory,
        isPinned: false,
        pollData: pollData,
        quizData: quizData,
        clientMessageId: clientMessageId,
      );
      await _localStorage.saveMessage(localGroupMsg, groupId);

      final WriteBatch batch = _firestore.batch();
      batch.set(messageRef, messageData);

      if (replyToMessageId != null && replyToMessageId.isNotEmpty) {
        final parentRef =
            groupRef.collection('messages').doc(replyToMessageId);
        batch.set(
            parentRef,
            {'replyThreadCount': FieldValue.increment(1)},
            SetOptions(merge: true));
      }

      final String previewText =
          _buildMessagePreviewText(message, type, category: messageCategory);

      final Map<String, int> updatedUnreadCounts =
          Map<String, int>.from(group.unreadCounts);
      for (final memberId in group.members) {
        if (memberId == senderId) {
          updatedUnreadCounts[memberId] = 0;
        } else {
          updatedUnreadCounts[memberId] =
              (updatedUnreadCounts[memberId] ?? 0) + 1;
        }
      }

      batch.update(groupRef, {
        'lastMessage': previewText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
        'unreadCounts': updatedUnreadCounts,
      });

      final String publicSenderLabel =
          isTeacherSender ? group.teacherName : 'Student';
      for (final memberId in group.members) {
        if (memberId == senderId) continue;
        if (group.mutedByUsers.contains(memberId)) continue;

        final notifRef = _firestore.collection('notifications').doc();
        batch.set(notifRef, {
          'notificationId': notifRef.id,
          'senderId': isTeacherSender ? senderId : 'student_hidden',
          'receiverId': memberId,
          'groupId': groupId,
          'title': group.name,
          'body': '$publicSenderLabel: $previewText',
          'type': 'group_message',
          'messageCategory': messageCategory,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }

      await batch.commit();
    } catch (e) {
      _handleError('sendGroupMessage', e);
      throw Exception('Failed to send group message: $e');
    }
  }

  Future<void> markAsSeen(String chatId, String currentUserId) async {
    try {
      final db = await _localStorage.database;
      await db.update(
        'local_messages',
        {'status': 'seen'},
        where: 'chatRoomId = ? AND receiverId = ?',
        whereArgs: [chatId, currentUserId],
      );

      final querySnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      batch.set(
          _firestore.collection('chats').doc(chatId),
          {
            'unreadCount': 0,
            'unreadFor': '',
            'unreadCount_$currentUserId': 0,
          },
          SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      _handleError('markAsSeen', e);
    }
  }

  Future<void> markGroupMessagesAsSeen(
      String groupId, String currentUserId) async {
    if (groupId.trim().isEmpty || currentUserId.trim().isEmpty) return;
    try {
      final db = await _localStorage.database;
      await db.update(
        'local_messages',
        {'status': 'seen'},
        where: 'chatRoomId = ? AND senderId != ?',
        whereArgs: [groupId, currentUserId],
      );

      final groupRef = _firestore.collection('groups').doc(groupId);
      await groupRef.set({
        'unreadCounts': {currentUserId: 0},
      }, SetOptions(merge: true));
    } catch (e) {
      _handleError('markGroupMessagesAsSeen', e);
    }
  }

  Future<String> _uploadFileToStorage(File file, String folder) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final ref = _storage.ref().child('chat_attachments/$folder/$fileName');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      _handleError('_uploadFileToStorage', e);
      rethrow;
    }
  }

  Future<void> sendImageFile({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required File file,
    String messageCategory = 'general',
  }) async {
    final url = await _uploadFileToStorage(file, 'images');
    await sendMessage(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      message: url,
      type: 'image',
      messageCategory: messageCategory,
    );
  }

  Future<void> sendVideoFile({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required File file,
    String messageCategory = 'general',
  }) async {
    final url = await _uploadFileToStorage(file, 'videos');
    await sendMessage(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      message: url,
      type: 'video',
      messageCategory: messageCategory,
    );
  }

  Future<void> sendDocumentFile({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required File file,
    required String fileName,
    String messageCategory = 'general',
  }) async {
    final url = await _uploadFileToStorage(file, 'documents');
    await sendMessage(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      message: url,
      type: 'document',
      mediaMetaData: {'fileName': fileName},
      messageCategory: messageCategory,
    );
  }

  Future<void> sendAudioFile({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required File file,
  }) async {
    final url = await _uploadFileToStorage(file, 'audio');
    await sendMessage(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      message: url,
      type: 'audio',
    );
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .snapshots(includeMetadataChanges: false)
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final List<MessageModel> incomingMessages = [];
        final List<DocumentReference> docsToDeleteFromCloud = [];

        for (final doc in snapshot.docs) {
          final data = doc.data();
          data['messageId'] = doc.id;
          final msg = MessageModel.fromMap(data);
          incomingMessages.add(msg);

          if (_currentUserId.isNotEmpty && msg.receiverId == _currentUserId) {
            docsToDeleteFromCloud.add(doc.reference);
            if (msg.type == 'image' ||
                msg.type == 'video' ||
                msg.type == 'audio' ||
                msg.type == 'document') {
              _downloadAndCacheMediaLocally(msg.content, msg.messageId)
                  .then((localPath) {
                if (localPath != null) {
                  _localStorage.updateLocalMediaPath(
                    messageId: msg.messageId,
                    chatRoomId: chatId,
                    localPath: localPath,
                  );
                }
              });
            }
          }
        }

        await _localStorage.saveMessagesBatch(incomingMessages, chatId);

        if (docsToDeleteFromCloud.isNotEmpty) {
          final batch = _firestore.batch();
          for (final ref in docsToDeleteFromCloud) {
            batch.delete(ref);
          }
          await batch.commit().catchError((_) {});
        }
      }
    }, onError: (e) {
      _handleError('getMessages (Listener error)', e);
    });

    return _localStorage.streamLocalMessages(chatRoomId: chatId);
  }

  Stream<List<MessageModel>> getGroupMessagesStream(
    String groupId, {
    String? categoryFilter,
  }) {
    _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .snapshots(includeMetadataChanges: false)
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final List<MessageModel> incomingGroupMessages = [];

        for (final doc in snapshot.docs) {
          final data = doc.data();
          data['messageId'] = doc.id;
          final msg = MessageModel.fromMap(data);
          incomingGroupMessages.add(msg);

          if (_currentUserId.isNotEmpty &&
              msg.senderId != _currentUserId &&
              (msg.type == 'image' ||
                  msg.type == 'video' ||
                  msg.type == 'audio' ||
                  msg.type == 'document')) {
            _downloadAndCacheMediaLocally(msg.content, msg.messageId)
                .then((localPath) {
              if (localPath != null) {
                _localStorage.updateLocalMediaPath(
                  messageId: msg.messageId,
                  chatRoomId: groupId,
                  localPath: localPath,
                );
              }
            });
          }
        }

        await _localStorage.saveMessagesBatch(incomingGroupMessages, groupId);
      }
    }, onError: (e) {
      _handleError('getGroupMessagesStream (Listener error)', e);
    });

    return _localStorage.streamLocalMessages(
      chatRoomId: groupId,
      categoryFilter: categoryFilter,
    );
  }

  Future<List<MessageModel>> getPaginatedMessages({
    required String chatOrGroupId,
    required bool isGroup,
    DocumentSnapshot? lastDocument,
    int limit = 30,
  }) async {
    try {
      final localMsgs = await _localStorage.getLocalMessages(
        chatRoomId: chatOrGroupId,
        limit: limit,
      );
      if (localMsgs.isNotEmpty) {
        return localMsgs;
      }

      final String rootCollection = isGroup ? 'groups' : 'chats';
      Query> query = _firestore
          .collection(rootCollection)
          .doc(chatOrGroupId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snap = await query.get();
      final list = snap.docs.map((doc) {
        final data = doc.data();
        data['messageId'] = doc.id;
        return MessageModel.fromMap(data);
      }).toList();

      await _localStorage.saveMessagesBatch(list, chatOrGroupId);
      return list;
    } catch (e) {
      _handleError('getPaginatedMessages', e);
      return const [];
    }
  }

  Future<DocumentReference>> _resolveMessageRef(
      String chatOrGroupId, String messageId,
      {bool? isGroup}) async {
    if (isGroup == true) {
      return _firestore
          .collection('groups')
          .doc(chatOrGroupId)
          .collection('messages')
          .doc(messageId);
    }
    if (isGroup == false) {
      return _firestore
          .collection('chats')
          .doc(chatOrGroupId)
          .collection('messages')
          .doc(messageId);
    }

    final chatMsgRef = _firestore
        .collection('chats')
        .doc(chatOrGroupId)
        .collection('messages')
        .doc(messageId);
    final chatMsgSnap = await chatMsgRef.get();
    if (chatMsgSnap.exists) return chatMsgRef;

    return _firestore
        .collection('groups')
        .doc(chatOrGroupId)
        .collection('messages')
        .doc(messageId);
  }

  Future<void> editMessage(
      String chatId, String messageId, String newText,
      {bool? isGroup}) async {
    try {
      await _localStorage.updateMessageContentLocally(
        messageId: messageId,
        chatRoomId: chatId,
        newContent: newText,
      );

      final ref = await _resolveMessageRef(chatId, messageId, isGroup: isGroup);
      await ref.update({
        'content': newText,
        'isEdited': true,
        'editTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _handleError('editMessage', e);
    }
  }

  Future<void> deleteMessageForEveryone(
      String chatId, String messageId,
      {bool? isGroup}) async {
    try {
      await _localStorage.deleteMessageForEveryoneLocally(messageId, chatId);

      final ref = await _resolveMessageRef(chatId, messageId, isGroup: isGroup);
      await ref.delete();
    } catch (e) {
      _handleError('deleteMessageForEveryone', e);
    }
  }

  Future<void> deleteMessageForMe(
      String chatId, String messageId, String userId,
      {bool? isGroup}) async {
    try {
      await _localStorage.deleteMessageForMeLocally(messageId, chatId, userId);

      final ref = await _resolveMessageRef(chatId, messageId, isGroup: isGroup);
      await ref.update({
        'deletedForUsers': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      _handleError('deleteMessageForMe', e);
    }
  }

  Future<void> reactMessage(
      String chatId, String messageId, String userId, String emoji,
      {bool? isGroup}) async {
    try {
      final ref = await _resolveMessageRef(chatId, messageId, isGroup: isGroup);
      await ref.set({
        'reactions': {userId: emoji}
      }, SetOptions(merge: true));
    } catch (e) {
      _handleError('reactMessage', e);
    }
  }

  Future<void> toggleStarMessage({
    required String chatId,
    required String messageId,
    required String userId,
    required bool star,
    bool? isGroup,
  }) async {
    try {
      final ref = await _resolveMessageRef(chatId, messageId, isGroup: isGroup);
      await ref.update({
        'starredBy': star
            ? FieldValue.arrayUnion([userId])
            : FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      _handleError('toggleStarMessage', e);
    }
  }

  Future<void> togglePinChat(
      String chatId, String userId, bool pin) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'pinnedBy': pin
            ? FieldValue.arrayUnion([userId])
            : FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      _handleError('togglePinChat', e);
    }
  }

  Future<void> toggleMuteChat(
      String chatId, String userId, bool mute) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'mutedBy': mute
            ? FieldValue.arrayUnion([userId])
            : FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      _handleError('toggleMuteChat', e);
    }
  }

  Future<void> toggleArchiveChat(
      String chatId, String userId, bool archive) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'archivedBy': archive
            ? FieldValue.arrayUnion([userId])
            : FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      _handleError('toggleArchiveChat', e);
    }
  }

  Future<void> markChatAsUnread(String chatId, String userId) async {
    try {
      await _firestore.collection('chats').doc(chatId).set({
        'unreadCount_$userId': 1,
        'unreadFor': userId,
        'unreadCount': 1,
      }, SetOptions(merge: true));
    } catch (e) {
      _handleError('markChatAsUnread', e);
    }
  }

  Future<void> toggleBlockChat(
      String chatId, String userId, bool block) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'blockedBy': block
            ? FieldValue.arrayUnion([userId])
            : FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      _handleError('toggleBlockChat', e);
    }
  }

  Future<void> reportAbuseOrSpam({
    required String reporterId,
    required String targetId,
    required String targetType,
    required String reason,
    String? chatOrGroupId,
    String? messageId,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'reporterId': reporterId,
        'targetId': targetId,
        'targetType': targetType,
        'reason': reason,
        'chatOrGroupId': chatOrGroupId,
        'messageId': messageId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _handleError('reportAbuseOrSpam', e);
    }
  }

  Stream<List<MessageModel>> getSharedMediaDocsLinksStream({
    required String chatOrGroupId,
    required bool isGroup,
  }) {
    final String rootCollection = isGroup ? 'groups' : 'chats';
    return _firestore
        .collection(rootCollection)
        .doc(chatOrGroupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        data['messageId'] = doc.id;
        return MessageModel.fromMap(data);
      }).where((m) => !m.isDeletedForEveryone).toList();
    }).handleError((e) {
      _handleError('getSharedMediaDocsLinksStream', e);
    });
  }

  Future<String> exportChatTranscript({
    required String chatOrGroupId,
    required bool isGroup,
    required String currentUserId,
    required bool isViewerTeacherOfGroup,
  }) async {
    try {
      final localList = await _localStorage.getLocalMessages(
        chatRoomId: chatOrGroupId,
        limit: 500,
      );

      final StringBuffer buffer = StringBuffer();
      for (final msg in localList.reversed) {
        if (msg.isDeletedForEveryone ||
            msg.deletedForUsers.contains(currentUserId)) {
          continue;
        }
        final senderLabel = isGroup
            ? msg.getVisibleSenderName(
                currentUserId: currentUserId,
                isViewerTeacherOfGroup: isViewerTeacherOfGroup,
              )
            : (msg.senderId == currentUserId ? 'Me' : 'Participant');
        final timeStr =
            msg.timestamp != null ? msg.timestamp!.toIso8601String() : '';
        buffer.writeln('[$timeStr] $senderLabel: ${msg.content}');
      }
      return buffer.toString();
    } catch (e) {
      _handleError('exportChatTranscript', e);
      return '';
    }
  }

  Future<void> replyMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String message,
    required String replyToMessageId,
    String? replyToText,
  }) async {
    await sendMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      type: 'text',
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
    );
  }

  Future<void> forwardMessage({
    required String targetChatId,
    required String senderId,
    required String receiverId,
    required String message,
    required String type,
    Map<String, dynamic>? mediaMetaData,
  }) async {
    await sendMessage(
      chatId: targetChatId,
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      type: type,
      mediaMetaData: mediaMetaData,
      isForwarded: true,
    );
  }

  Future<void> sendImage(
      String chatId, String senderId, String receiverId, String url) async {
    await sendMessage(
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        message: url,
        type: 'image');
  }

  Future<void> sendVideo(
      String chatId, String senderId, String receiverId, String url) async {
    await sendMessage(
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        message: url,
        type: 'video');
  }

  Future<void> sendDocument(String chatId, String senderId, String receiverId,
      String url, String fileName) async {
    await sendMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      message: url,
      type: 'document',
      mediaMetaData: {'fileName': fileName},
    );
  }

  Future<void> sendAudio(
      String chatId, String senderId, String receiverId, String url) async {
    await sendMessage(
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        message: url,
        type: 'audio');
  }

  Future<void> sendVoice(
      String chatId, String senderId, String receiverId, String url) async {
    await sendMessage(
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        message: url,
        type: 'voice');
  }

  Future<void> sendLocation(String chatId, String senderId, String receiverId,
      double latitude, double longitude) async {
    await sendMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      message: '$latitude,$longitude',
      type: 'location',
      mediaMetaData: {'latitude': latitude, 'longitude': longitude},
    );
  }

  void _handleError(String methodName, dynamic error) {
    log('[@ChatService] Error inside $methodName: $error');
  }
}
