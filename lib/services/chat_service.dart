import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // USER STATUS & TYPING INDICATORS
  // ==========================================

  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': isOnline ? 'Online' : 'Offline',
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _handleError('updateOnlineStatus', e);
    }
  }

  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('typing')
          .doc(userId)
          .set({
        'isTyping': isTyping,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _handleError('updateTypingStatus', e);
    }
  }

  Stream<Map<String, dynamic>> getUserStatusStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      return {
        'status': data?['status'] ?? 'Offline',
        'lastSeen': data?['lastSeen'] as Timestamp?,
      };
    });
  }

  Stream<bool> getTypingStatusStream(String chatId, String userId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.data()?['isTyping'] ?? false);
  }

  // ==========================================
  // ONE-TO-ONE CHAT LOGIC & LIFECYCLE
  // ==========================================

  Future<void> createOrInitializeChat({
    required String chatId,
    required String teacherId,
    required String studentId,
    required String teacherName,
    required String studentName,
    required String teacherImage,
    required String studentImage,
  }) async {
    try {
      final chatRef = _firestore.collection('chats').doc(chatId);
      final doc = await chatRef.get();

      if (!doc.exists) {
        await chatRef.set({
          'chatId': chatId,
          'teacherId': teacherId,
          'studentId': studentId,
          'teacherName': teacherName,
          'studentName': studentName,
          'teacherImage': teacherImage,
          'studentImage': studentImage,
          'participants': [teacherId, studentId],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': 0,
          'isGroup': false,
          'pinnedBy': [],
          'blockedBy': [],
        });
      }
    } catch (e) {
      _handleError('createOrInitializeChat', e);
    }
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String message,
    required String type,
    String? replyToMessageId,
    Map<String, dynamic>? mediaMetaData,
  }) async {
    try {
      final batch = _firestore.batch();
      final chatRef = _firestore.collection('chats').doc(chatId);
      final messageRef = chatRef.collection('messages').doc();

      final Map<String, dynamic> messageData = {
        'messageId': messageRef.id,
        'senderId': senderId,
        'receiverId': receiverId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': type,
        'status': 'sent', 
        'isDeletedForEveryone': false,
        'deletedForUsers': [],
        'starredBy': [],
        'reactions': {},
      };

      if (replyToMessageId != null) {
        messageData['replyToMessageId'] = replyToMessageId;
      }
      if (mediaMetaData != null) {
        messageData['mediaMetaData'] = mediaMetaData;
      }

      batch.set(messageRef, messageData);

      batch.update(chatRef, {
        'lastMessage': type == 'text' ? message : '[$type]',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (e) {
      _handleError('sendMessage', e);
    }
  }

  // ==========================================
  // READ RECEIPTS & DELIVERY STATUS
  // ==========================================

  Future<void> updateMessageDeliveryStatus(String chatId, String messageId, String status) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'status': status});
    } catch (e) {
      _handleError('updateMessageDeliveryStatus', e);
    }
  }

  Future<void> markChatMessagesAsSeen(String chatId, String currentUserId) async {
    try {
      final querySnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isNotEqualTo: 'seen')
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'status': 'seen'}); 
      }

      batch.update(_firestore.collection('chats').doc(chatId), {
        'unreadCount': 0,
      });

      await batch.commit();
    } catch (e) {
      _handleError('markChatMessagesAsSeen', e);
    }
  }

  // ==========================================
  // ADVANCED MESSAGING FEATURES
  // ==========================================

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'message': newText,
        'isEdited': true,
        'editTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _handleError('editMessage', e);
    }
  }

  Future<void> deleteMessageForEveryone(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'message': 'This message was deleted',
        'type': 'text',
        'isDeletedForEveryone': true,
      });
    } catch (e) {
      _handleError('deleteMessageForEveryone', e);
    }
  }

  Future<void> deleteMessageForMe(String chatId, String messageId, String userId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'deletedForUsers': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      _handleError('deleteMessageForMe', e);
    }
  }

  Future<void> addMessageReaction(String chatId, String messageId, String userId, String emoji) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'reactions.$userId': emoji,
      });
    } catch (e) {
      _handleError('addMessageReaction', e);
    }
  }

  Future<void> toggleStarMessage(String chatId, String messageId, String userId, bool isStarred) async {
    try {
      final updateData = isStarred
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]);
      
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'starredBy': updateData});
    } catch (e) {
      _handleError('toggleStarMessage', e);
    }
  }

  // ==========================================
  // GROUP CHAT LIFECYCLE & MANAGEMENT
  // ==========================================

  Future<void> createGroupChat({
    required String groupId,
    required String groupName,
    required String groupImage,
    required String creatorId,
    required List<String> members,
  }) async {
    try {
      await _firestore.collection('groups').doc(groupId).set({
        'groupId': groupId,
        'groupName': groupName,
        'groupImage': groupImage,
        'createdBy': creatorId,
        'createdAt': FieldValue.serverTimestamp(),
        'members': members,
        'lastMessage': 'Group created by administration',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'admins': [creatorId],
      });
    } catch (e) {
      _handleError('createGroupChat', e);
    }
  }

  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String message,
    required String type,
    String? replyToMessageId,
  }) async {
    try {
      final batch = _firestore.batch();
      final groupRef = _firestore.collection('groups').doc(groupId);
      final messageRef = groupRef.collection('messages').doc();

      final Map<String, dynamic> messageData = {
        'messageId': messageRef.id,
        'senderId': senderId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': type,
        'isDeletedForEveryone': false,
        'deletedForUsers': [],
        'readBy': [senderId],
        'deliveredTo': [senderId],
      };

      if (replyToMessageId != null) {
        messageData['replyToMessageId'] = replyToMessageId;
      }

      batch.set(messageRef, messageData);

      batch.update(groupRef, {
        'lastMessage': type == 'text' ? message : '[$type]',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      _handleError('sendGroupMessage', e);
    }
  }

  // ==========================================
  // STREAMS FOR RENDERING UI
  // ==========================================

  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getGroupMessagesStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getChatListStream(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getGroupListStream(String userId) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // ==========================================
  // PRIVATE ERROR HANDLING UTILITY
  // ==========================================

  void _handleError(String methodName, dynamic error) {
    throw Exception('ChatService Error inside $methodName: $error');
  }
}
