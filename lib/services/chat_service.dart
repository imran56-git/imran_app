import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import '../models/group_model.dart';
import '../models/message_model.dart';
import '../widgets/permanent_avatar.dart';
import 'local_chat_storage_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalChatStorageService _localStorage = LocalChatStorageService();
  final Map<String, DateTime> _recentClientMessages = <String, DateTime>{};

  static const String officialSenderId = 'OFFICIAL_FYBTT_DESK';
  static const String legacyOfficialSenderId = 'fybtt_official';

  String get _currentUserId => _auth.currentUser?.uid ?? '';

  static bool isOfficialFeeThread(String docId, Map<String, dynamic> data) {
    final String chatId = (data['chatId'] ?? docId).toString().trim();
    final String lastSenderId = (data['lastSenderId'] ?? '').toString().trim();
    final String teacherId = (data['teacherId'] ?? '').toString().trim();
    final String senderId = (data['senderId'] ?? '').toString().trim();
    final String teacherName =
        (data['teacherName'] ?? '').toString().trim().toLowerCase();
    final String chatCategory =
        (data['chatCategory'] ?? '').toString().trim().toLowerCase();
    final List<dynamic> participants =
        (data['participants'] as List<dynamic>?) ?? const [];

    final bool hasOfficialParticipant = participants.any((p) {
      final id = p.toString().trim();
      return id == officialSenderId || id == legacyOfficialSenderId;
    });

    return data['isOfficial'] == true ||
        chatId.startsWith('official_desk_') ||
        docId.startsWith('official_desk_') ||
        chatCategory == 'official_fees' ||
        lastSenderId == officialSenderId ||
        lastSenderId == legacyOfficialSenderId ||
        teacherId == officialSenderId ||
        teacherId == legacyOfficialSenderId ||
        senderId == officialSenderId ||
        senderId == legacyOfficialSenderId ||
        teacherName == 'fybtt official' ||
        hasOfficialParticipant;
  }

  static bool isOfficialChatIdOrReceiver(String chatId, [String receiverId = '']) {
    final cleanChatId = chatId.trim();
    final cleanReceiver = receiverId.trim();
    return cleanChatId.startsWith('official_desk_') ||
        cleanReceiver == officialSenderId ||
        cleanReceiver == legacyOfficialSenderId;
  }

  Future<Map<String, dynamic>?> _safeDocData(
      String collection, String docId) async {
    if (docId.trim().isEmpty) return null;
    try {
      final doc = await _firestore.collection(collection).doc(docId).get();
      if (doc.exists && doc.data() != null) return doc.data();
    } catch (_) {}
    return null;
  }

  bool _resolveIsVerified(
    List<Map<String, dynamic>?> sources, {
    bool fallback = false,
  }) {
    bool hasAnySource = false;
    for (final src in sources) {
      if (src == null) continue;
      hasAnySource = true;
      if (src['isVerified'] == true ||
          src['status'] == 'approved' ||
          src['verificationStatus'] == 'verified') {
        return true;
      }
    }
    return hasAnySource ? false : fallback;
  }

  String _pickNonEmpty(
    List<Map<String, dynamic>?> sources,
    List<String> keys, {
    bool excludeGeneric = false,
  }) {
    for (final src in sources) {
      if (src == null) continue;
      for (final key in keys) {
        final val = src[key]?.toString().trim() ?? '';
        if (val.isEmpty) continue;
        if (excludeGeneric && (val == 'Me' || val == 'User')) continue;
        return val;
      }
    }
    return '';
  }

  Future<Map<String, dynamic>?> getUserProfile(
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
        if (data['isGroup'] == true) continue;
        if (isOfficialFeeThread(doc.id, data)) continue;

        final List<dynamic> deletedBy =
            (data['deletedBy'] as List<dynamic>?) ?? const [];
        if (deletedBy.contains(userId)) continue;

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

  Stream<int> getTotalUnreadFeesCountStream(String userId) {
    if (userId.trim().isEmpty) return Stream.value(0);
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['isGroup'] == true) continue;
        if (!isOfficialFeeThread(doc.id, data)) continue;

        final List<dynamic> deletedBy =
            (data['deletedBy'] as List<dynamic>?) ?? const [];
        if (deletedBy.contains(userId)) continue;

        if (data.containsKey('unreadCount_$userId')) {
          total += (data['unreadCount_$userId'] as num?)?.toInt() ?? 0;
        } else if (data['unreadFor'] == userId) {
          total += (data['unreadCount'] as num?)?.toInt() ?? 0;
        }
      }
      return total;
    }).handleError((e) {
      _handleError('getTotalUnreadFeesCountStream', e);
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
          .update(statusData)
          .catchError((_) {});
      await _firestore
          .collection('teachers')
          .doc(userId)
          .update(statusData)
          .catchError((_) {});
      await _firestore
          .collection('students')
          .doc(userId)
          .update(statusData)
          .catchError((_) {});
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

  Stream<Map<String, dynamic>> getUserStatusStream(
      String userId, bool isTeacher) {
    if (userId.trim().isEmpty) {
      return Stream.value(
          {'status': 'Offline', 'lastSeen': null, 'isOnline': false});
    }

    final String primaryCollection = isTeacher ? 'teachers' : 'students';

    Map<String, dynamic> normalizeProfileMap(Map<String, dynamic> data) {
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
      final String resolvedImageUrl = (data['profileImageUrl'] ??
              data['photoUrl'] ??
              data['profilePic'] ??
              data['profileUrl'] ??
              '')
          .toString()
          .trim();
      map['profileImageUrl'] = resolvedImageUrl;
      if (resolvedImageUrl.isNotEmpty) {
        unawaited(PermanentAvatarStorage.precacheAvatar(
          userId: userId,
          imageUrl: resolvedImageUrl,
        ));
      }
      map['isVerified'] = data['isVerified'] == true ||
          data['status'] == 'approved' ||
          data['verificationStatus'] == 'verified';
      return map;
    }

    return _firestore
        .collection(primaryCollection)
        .doc(userId)
        .snapshots()
        .asyncMap((doc) async {
      if (doc.exists && doc.data() != null) {
        return normalizeProfileMap(doc.data()!);
      }

      final userData = await _safeDocData('users', userId);
      if (userData != null) {
        return normalizeProfileMap(userData);
      }

      final String altCollection = isTeacher ? 'students' : 'teachers';
      final altData = await _safeDocData(altCollection, userId);
      if (altData != null) {
        return normalizeProfileMap(altData);
      }

      return {'status': 'Offline', 'lastSeen': null, 'isOnline': false};
    }).handleError((error) {
      _handleError('getUserStatusStream', error);
    });
  }

  String getChatRoomId(String user1, String user2) {
    if (user1.trim().isEmpty || user2.trim().isEmpty) return '';
    return '${user1.trim()}_${user2.trim()}';
  }

  Future<void> createOrInitializeChat({
    required String teacherId,
    required String studentId,
    required String teacherName,
    required String studentName,
    required String teacherImage,
    required String studentImage,
    bool? isTeacherVerified,
    bool? isStudentVerified,
  }) async {
    try {
      final String cleanTeacherId = teacherId.trim();
      final String cleanStudentId = studentId.trim();
      final String chatId = '${cleanTeacherId}_$cleanStudentId';
      final chatRef = _firestore.collection('chats').doc(chatId);

      final results = await Future.wait([
        chatRef.get(),
        _safeDocData('teachers', cleanTeacherId),
        _safeDocData('users', cleanTeacherId),
        _safeDocData('students', cleanStudentId),
        _safeDocData('users', cleanStudentId),
      ]);

      final doc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final teacherData = results[1] as Map<String, dynamic>?;
      final teacherUserData = results[2] as Map<String, dynamic>?;
      final studentData = results[3] as Map<String, dynamic>?;
      final studentUserData = results[4] as Map<String, dynamic>?;

      final existingData = doc.data();
      final existingProfiles =
          existingData?['userProfiles'] as Map<String, dynamic>?;
      final existingTeacherProfile =
          existingProfiles?[cleanTeacherId] as Map<String, dynamic>?;
      final existingStudentProfile =
          existingProfiles?[cleanStudentId] as Map<String, dynamic>?;

      final String resolvedTeacherName = (teacherName.trim().isNotEmpty &&
              teacherName.trim() != 'Me' &&
              teacherName.trim() != 'User')
          ? teacherName.trim()
          : _pickNonEmpty(
              [teacherData, teacherUserData],
              const ['fullName', 'name', 'displayName', 'teacherName'],
              excludeGeneric: true,
            );

      final String resolvedStudentName = (studentName.trim().isNotEmpty &&
              studentName.trim() != 'Me' &&
              studentName.trim() != 'User')
          ? studentName.trim()
          : _pickNonEmpty(
              [studentData, studentUserData],
              const ['fullName', 'name', 'displayName', 'studentName'],
              excludeGeneric: true,
            );

      final String resolvedTeacherImage = teacherImage.trim().isNotEmpty
          ? teacherImage.trim()
          : _pickNonEmpty(
              [teacherData, teacherUserData],
              const ['profileImageUrl', 'photoUrl', 'profilePic', 'profileUrl'],
            );

      final String resolvedStudentImage = studentImage.trim().isNotEmpty
          ? studentImage.trim()
          : _pickNonEmpty(
              [studentData, studentUserData],
              const ['profileImageUrl', 'photoUrl', 'profilePic', 'profileUrl'],
            );

      final bool resolvedTeacherVerified = isTeacherVerified ??
          _resolveIsVerified(
            [teacherData, teacherUserData],
            fallback: existingTeacherProfile?['isVerified'] == true,
          );

      final bool resolvedStudentVerified = isStudentVerified ??
          _resolveIsVerified(
            [studentData, studentUserData],
            fallback: existingStudentProfile?['isVerified'] == true,
          );

      if (resolvedTeacherImage.isNotEmpty) {
        unawaited(PermanentAvatarStorage.precacheAvatar(
          userId: cleanTeacherId,
          imageUrl: resolvedTeacherImage,
        ));
      }
      if (resolvedStudentImage.isNotEmpty) {
        unawaited(PermanentAvatarStorage.precacheAvatar(
          userId: cleanStudentId,
          imageUrl: resolvedStudentImage,
        ));
      }

      final Map<String, dynamic> updateData = {
        'chatId': chatId,
        'teacherId': cleanTeacherId,
        'studentId': cleanStudentId,
        'participants': [cleanTeacherId, cleanStudentId]..sort(),
        'isGroup': false,
      };

      if (resolvedTeacherName.isNotEmpty) {
        updateData['teacherName'] = resolvedTeacherName;
      }
      if (resolvedStudentName.isNotEmpty) {
        updateData['studentName'] = resolvedStudentName;
      }
      if (resolvedTeacherImage.isNotEmpty) {
        updateData['teacherImage'] = resolvedTeacherImage;
      }
      if (resolvedStudentImage.isNotEmpty) {
        updateData['studentImage'] = resolvedStudentImage;
      }

      updateData['userProfiles'] = {
        cleanTeacherId: {
          if (resolvedTeacherName.isNotEmpty) 'name': resolvedTeacherName,
          if (resolvedTeacherImage.isNotEmpty) 'image': resolvedTeacherImage,
          'isVerified': resolvedTeacherVerified,
        },
        cleanStudentId: {
          if (resolvedStudentName.isNotEmpty) 'name': resolvedStudentName,
          if (resolvedStudentImage.isNotEmpty) 'image': resolvedStudentImage,
          'isVerified': resolvedStudentVerified,
        },
      };

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

  String _buildMessagePreviewText(
    String message,
    String type, {
    String category = 'general',
    String? caption,
    List<String>? mediaUrls,
  }) {
    final String cleanCaption = caption?.trim() ?? '';
    if (category == 'poll' || type == 'poll') return '📊 Poll: $message';
    if (category == 'quiz' || type == 'quiz') return '📝 Quiz: $message';
    if (category == 'homework') return '📚 Homework: $message';
    if (category == 'announcement') return '📢 Announcement: $message';
    if (category == 'study_material') return '📖 Study Material: $message';

    if (type == 'album') {
      final count = mediaUrls != null && mediaUrls.isNotEmpty ? mediaUrls.length : 2;
      return cleanCaption.isNotEmpty ? '🖼️ $count Photos: $cleanCaption' : '🖼️ $count Photos';
    }
    if (type == 'image') {
      return cleanCaption.isNotEmpty ? '📷 Photo: $cleanCaption' : '📷 Photo';
    }
    if (type == 'video') {
      return cleanCaption.isNotEmpty ? '🎥 Video: $cleanCaption' : '🎥 Video';
    }
    if (type == 'audio' || type == 'voice') return '🎵 Voice message';
    if (type == 'document') return '📄 Document';
    if (type == 'location') return '📍 Location';
    return message;
  }

  List<String> extractMediaUrlsFromMessage(MessageModel msg) {
    final List<String> urls = <String>[];
    if (msg.mediaUrl != null && msg.mediaUrl!.startsWith('http')) {
      urls.add(msg.mediaUrl!);
    }
    if (msg.mediaUrls != null) {
      for (final u in msg.mediaUrls!) {
        if (u.startsWith('http') && !urls.contains(u)) urls.add(u);
      }
    }
    if (msg.mediaMetaData != null) {
      for (final key in const ['imageUrls', 'urls', 'mediaUrls']) {
        final raw = msg.mediaMetaData![key];
        if (raw is List) {
          for (final item in raw) {
            final s = item.toString();
            if (s.startsWith('http') && !urls.contains(s)) {
              urls.add(s);
            }
          }
        }
      }
      for (final key in const ['imageUrl', 'audioUrl', 'videoUrl', 'fileUrl', 'url']) {
        final val = msg.mediaMetaData![key]?.toString();
        if (val != null && val.startsWith('http') && !urls.contains(val)) {
          urls.add(val);
        }
      }
    }
    if (msg.content.startsWith('http') && msg.type != 'text') {
      if (!urls.contains(msg.content)) {
        urls.add(msg.content);
      }
    }
    return urls;
  }

  Future<void> deleteFirebaseStorageFilesSafe(List<String> urls) async {
    for (final url in urls) {
      if (url.isEmpty || !url.startsWith('http')) continue;
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } catch (_) {}
    }
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
    String? caption,
    List<String>? mediaUrls,
  }) async {
    if (isOfficialChatIdOrReceiver(chatId, receiverId)) {
      throw Exception('FYBTT official channel is read-only.');
    }

    try {
      final String dedupeKey =
          clientMessageId ?? '${senderId}_${receiverId}_${type}_$message';
      if (_isDuplicateSubmission(dedupeKey)) return;

      String correctChatId = chatId.trim();
      if (correctChatId.isEmpty) {
        correctChatId = '${receiverId}_$senderId';
      }

      final chatRef = _firestore.collection('chats').doc(correctChatId);
      final chatDoc = await chatRef.get();

      int disappearingHours = 0;
      if (chatDoc.exists && chatDoc.data() != null) {
        final chatData = chatDoc.data()!;
        if (isOfficialFeeThread(correctChatId, chatData)) {
          throw Exception('FYBTT official channel is read-only.');
        }
        final List<dynamic> blockedBy =
            (chatData['blockedBy'] as List<dynamic>?) ?? const [];
        if (blockedBy.isNotEmpty) {
          throw Exception('Cannot send message. This conversation is blocked.');
        }
        disappearingHours =
            (chatData['disappearingDurationHours'] as num?)?.toInt() ?? 0;
      }

      DateTime expiresAt = DateTime.now().add(const Duration(days: 7));
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
        'expiresAt': Timestamp.fromDate(expiresAt),
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
        senderId: senderId,
        receiverId: receiverId,
        content: message,
        type: type,
        timestamp: DateTime.now(),
        status: 'sent',
        isDeletedForEveryone: false,
        deletedForUsers: const <String>[],
        starredBy: const <String>[],
        reactions: const <String, dynamic>{},
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
          localMsg, correctChatId);

      final batch = _firestore.batch();
      batch.set(messageRef, messageData);

      final String previewText = _buildMessagePreviewText(
        message,
        type,
        category: messageCategory,
        caption: caption,
        mediaUrls: mediaUrls,
      );

      int currentUnread = 0;
      if (chatDoc.exists && chatDoc.data() != null) {
        final data = chatDoc.data()!;
        if (data.containsKey('unreadCount_$receiverId')) {
          currentUnread =
              (data['unreadCount_$receiverId'] as num?)?.toInt() ?? 0;
        } else if (data['unreadFor'] == receiverId) {
          currentUnread = (data['unreadCount'] as num?)?.toInt() ?? 0;
        }
      }

      final List<String> sortedParticipants = [senderId, receiverId]..sort();

      final Map<String, dynamic> chatUpdateData = {
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
      };

      batch.set(chatRef, chatUpdateData, SetOptions(merge: true));

      final notificationRef = _firestore.collection('notifications').doc();
      batch.set(notificationRef, {
        'notificationId': notificationRef.id,
        'senderId': senderId,
        'receiverId': receiverId,
        'chatId': correctChatId,
        'title': 'New Message',
        'body': previewText,
        'type': type,
        'mediaUrl': (mediaUrls != null && mediaUrls.isNotEmpty)
            ? mediaUrls.first
            : (type == 'image' || type == 'video')
                ? message
                : null,
        'caption': caption?.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      await batch.commit();
    } catch (e) {
      _handleError('sendMessage', e);
      throw Exception('Failed to send message: $e');
    }
  }

  Future<void> sendMediaAlbum({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required List<File> files,
    String? caption,
    String messageCategory = 'general',
  }) async {
    if (files.isEmpty) return;

    if (files.length == 1) {
      await sendImageFile(
        chatRoomId: chatRoomId,
        senderId: senderId,
        receiverId: receiverId,
        file: files.first,
        caption: caption,
        messageCategory: messageCategory,
      );
      return;
    }

    final List<String> localOriginalPaths =
        files.map((f) => f.path).toList();

    final uploadFutures = files.map((file) => _uploadFileToStorage(file, 'images'));
    final List<String> uploadedUrls = await Future.wait(uploadFutures);

    await sendMessage(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      message: uploadedUrls.first,
      type: 'album',
      mediaUrls: uploadedUrls,
      caption: caption,
      messageCategory: messageCategory,
      mediaMetaData: {
        'imageUrls': uploadedUrls,
        'urls': uploadedUrls,
        'localFilePaths': localOriginalPaths,
        'count': uploadedUrls.length,
      },
    );
  }

  Future<void> markAsSeen(String chatId, String currentUserId) async {
    try {
      await _localStorage.markAllMessagesReadLocally(chatId);

      final querySnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          data['messageId'] = doc.id;
          final msg = MessageModel.fromMap(data);
          await _localStorage.processAndSaveIncomingMessage(msg, chatId);
          final mediaUrls = extractMediaUrlsFromMessage(msg);
          await deleteFirebaseStorageFilesSafe(mediaUrls);
          await doc.reference.delete().catchError((_) {});
        }
      }

      await _firestore.collection('chats').doc(chatId).set(
        {
          'unreadCount': 0,
          'unreadFor': '',
          'unreadCount_$currentUserId': 0,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      _handleError('markAsSeen', e);
    }
  }

  Future<void> markGroupMessagesAsSeen(
      String groupId, String currentUserId) async {
    if (groupId.trim().isEmpty || currentUserId.trim().isEmpty) return;
    try {
      await _localStorage.markAllMessagesReadLocally(groupId);

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
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      final ref = _storage.ref().child('chat_attachments/$folder/$fileName');

      SettableMetadata? metadata;
      if (folder == 'images') {
        metadata = SettableMetadata(contentType: 'image/jpeg');
      } else if (folder == 'videos') {
        metadata = SettableMetadata(contentType: 'video/mp4');
      } else if (folder == 'audio') {
        metadata = SettableMetadata(contentType: 'audio/mpeg');
      } else if (folder == 'documents') {
        final extension = p.extension(file.path).toLowerCase();
        String contentType;
        switch (extension) {
          case '.pdf':
            contentType = 'application/pdf';
            break;
          case '.doc':
            contentType = 'application/msword';
            break;
          case '.docx':
            contentType =
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            break;
          case '.xls':
            contentType = 'application/vnd.ms-excel';
            break;
          case '.xlsx':
            contentType =
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
            break;
          case '.ppt':
            contentType = 'application/vnd.ms-powerpoint';
            break;
          case '.pptx':
            contentType =
                'application/vnd.openxmlformats-officedocument.presentationml.presentation';
            break;
          case '.txt':
            contentType = 'text/plain';
            break;
          default:
            contentType = 'application/octet-stream';
            break;
        }
        metadata = SettableMetadata(contentType: contentType);
      }

      final uploadTask = await ref.putFile(file, metadata);
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
    String? caption,
    String messageCategory = 'general',
  }) async {
    final url = await _uploadFileToStorage(file, 'images');
    await sendMessage(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      message: url,
      type: 'image',
      caption: caption,
      messageCategory: messageCategory,
      mediaMetaData: {
        'imageUrl': url,
        'localFilePath': file.path,
      },
    );
  }

  Future<void> sendVideoFile({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required File file,
    String? caption,
    String messageCategory = 'general',
  }) async {
    final url = await _uploadFileToStorage(file, 'videos');
    await sendMessage(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      message: url,
      type: 'video',
      caption: caption,
      messageCategory: messageCategory,
      mediaMetaData: {
        'videoUrl': url,
        'localFilePath': file.path,
      },
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
      mediaMetaData: {
        'fileName': fileName,
        'fileUrl': url,
        'localFilePath': file.path,
      },
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
      mediaMetaData: {
        'audioUrl': url,
        'localFilePath': file.path,
      },
    );
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    if (chatId.trim().isEmpty) {
      return Stream.value(const <MessageModel>[]);
    }

    late final StreamController<List<MessageModel>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? firestoreSub;
    StreamSubscription<List<MessageModel>>? localSub;

    controller = StreamController<List<MessageModel>>(
      onListen: () {
        localSub = _localStorage
            .streamLocalMessages(chatRoomId: chatId)
            .listen(
          (messages) {
            if (!controller.isClosed) {
              controller.add(messages);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );

        firestoreSub = _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .snapshots(includeMetadataChanges: false)
            .listen((snapshot) async {
          if (snapshot.docs.isNotEmpty) {
            for (final doc in snapshot.docs) {
              final data = doc.data();
              data['messageId'] = doc.id;
              final msg = MessageModel.fromMap(data);

              if (_currentUserId.isNotEmpty &&
                  msg.receiverId == _currentUserId) {
                await _localStorage.processAndSaveIncomingMessage(msg, chatId);
                final mediaUrls = extractMediaUrlsFromMessage(msg);
                await deleteFirebaseStorageFilesSafe(mediaUrls);
                await doc.reference.delete().catchError((_) {});
              } else if (msg.senderId == _currentUserId) {
                final alreadyHas = await _localStorage.hasMessage(msg.messageId);
                if (!alreadyHas) {
                  await _localStorage.saveMessage(msg, chatId);
                }
              }
            }
          }
        }, onError: (e) {
          _handleError('getMessages (Listener error)', e);
        });
      },
      onCancel: () async {
        await firestoreSub?.cancel();
        await localSub?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<List<MessageModel>> getGroupMessagesStream(
    String groupId, {
    String? categoryFilter,
  }) {
    if (groupId.trim().isEmpty) {
      return Stream.value(const <MessageModel>[]);
    }

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
      Query<Map<String, dynamic>> query = _firestore
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
      return const <MessageModel>[];
    }
  }

  Future<DocumentReference> _resolveMessageRef(
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
    if (isOfficialChatIdOrReceiver(chatId)) return;
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
    if (isOfficialChatIdOrReceiver(chatId)) return;
    try {
      await _localStorage.deleteMessageForEveryoneLocally(messageId, chatId);

      final ref = await _resolveMessageRef(chatId, messageId, isGroup: isGroup);
      final snap = await ref.get();
      if (snap.exists && snap.data() != null) {
        final data = snap.data() as Map<String, dynamic>;
        data['messageId'] = snap.id;
        final msg = MessageModel.fromMap(data);
        final urls = extractMediaUrlsFromMessage(msg);
        await deleteFirebaseStorageFilesSafe(urls);
      }
      await ref.delete().catchError((_) {});
    } catch (e) {
      _handleError('deleteMessageForEveryone', e);
    }
  }

  Future<void> deleteMessageForMe(
      String chatId, String messageId, String userId,
      {bool? isGroup}) async {
    if (isOfficialChatIdOrReceiver(chatId)) return;
    try {
      await _localStorage.deleteMessageForMeLocally(messageId, chatId, userId);

      final ref = await _resolveMessageRef(chatId, messageId, isGroup: isGroup);
      await ref.update({
        'deletedForUsers': FieldValue.arrayUnion([userId]),
      }).catchError((_) {});
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
    if (isOfficialChatIdOrReceiver(chatId)) return;
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
    if (isOfficialChatIdOrReceiver(chatId)) return;
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
      String chatId, String senderId, String receiverId, String url,
      {String? caption}) async {
    await sendMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      message: url,
      type: 'image',
      caption: caption,
    );
  }

  Future<void> sendVideo(
      String chatId, String senderId, String receiverId, String url,
      {String? caption}) async {
    await sendMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      message: url,
      type: 'video',
      caption: caption,
    );
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
      type: 'audio',
    );
  }

  Future<void> sendVoice(
      String chatId, String senderId, String receiverId, String url) async {
    await sendMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      message: url,
      type: 'voice',
    );
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