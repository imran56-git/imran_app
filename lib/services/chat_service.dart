import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // USER STATUS & TYPING INDICATORS (ROLE-AWARE)
  // ==========================================

  Future<void> updateOnlineStatus(String userId, bool isOnline, bool isTeacher) async {
    try {
      final String collectionPath = isTeacher ? 'teachers' : 'students';

      await _firestore.collection(collectionPath).doc(userId).update({
        'isOnline': isOnline,
        'status': isOnline ? 'Online' : 'Offline',
        'lastSeen': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('users').doc(userId).update({
        'status': isOnline ? 'Online' : 'Offline',
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((_) {});

    } catch (e) {
      _handleError('updateOnlineStatus', e);
    }
  }

  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping) async {
    try {
      await _firestore
          .collection('typing')
          .doc(chatId)
          .set({
        userId: isTyping,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      _handleError('updateTypingStatus', e);
    }
  }

  Stream<Map<String, dynamic>> getUserStatusStream(String userId, bool isTeacher) {
    final String collectionPath = isTeacher ? 'teachers' : 'students';
    return _firestore.collection(collectionPath).doc(userId).snapshots().map((doc) {
      if (!doc.exists) return {'status': 'Offline', 'lastSeen': null, 'isOnline': false};
      final data = doc.data();
      return {
        'status': data?['status'] ?? 'Offline',
        'isOnline': data?['isOnline'] ?? false,
        'lastSeen': data?['lastSeen'] as Timestamp?,
      };
    });
  }

  // ==========================================
  // ONE-TO-ONE CHAT LOGIC & LIFECYCLE
  // ==========================================

  String getChatRoomId(String user1, String user2) {
    return user1.compareTo(user2) <= 0 ? '${user1}_$user2' : '${user2}_$user1';
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
          'lastMessageContent': 'Chat initialized', // ChatModel এর সাথে কি-ওয়ার্ড মেলাতে সিঙ্ক করা হলো
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount': 0,
          'isGroup': false,
          'pinnedBy': [],
          'blockedBy': [],
          'createdAt': FieldValue.serverTimestamp(),
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
        'content': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': type,
        'status': 'sent', 
        'isDeletedForEveryone': false,
        'deletedForUsers': [],
        'starredBy': [],
        'reactions': {},
      };

      if (replyToMessageId != null) messageData['replyToMessageId'] = replyToMessageId;
      if (mediaMetaData != null) messageData['mediaMetaData'] = mediaMetaData;

      batch.set(messageRef, messageData);

      String previewText = message;
      if (type == 'image') previewText = '📷 Photo';
      if (type == 'video') previewText = '🎥 Video';
      if (type == 'audio' || type == 'voice') previewText = '🎵 Voice message';
      if (type == 'document') previewText = '📄 Document';
      if (type == 'location') previewText = '📍 Location';

      batch.update(chatRef, {
        'lastMessageContent': previewText, // ChatModel মেলাতে সিঙ্ক
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (e) {
      _handleError('sendMessage', e);
    }
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MessageModel.fromMap(doc.data())).toList();
    });
  }

  // ==========================================
  // READ RECEIPTS & DELIVERY STATUS
  // ==========================================

  Future<void> markAsSeen(String chatId, String currentUserId) async {
    try {
      final querySnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      bool hasUnseen = false;

      for (var doc in querySnapshot.docs) {
        if (doc.data()['status'] != 'seen') {
          batch.update(doc.reference, {'status': 'seen'});
          hasUnseen = true;
        }
      }

      if (hasUnseen) {
        batch.update(_firestore.collection('chats').doc(chatId), {
          'unreadCount': 0,
        });
        await batch.commit();
      }
    } catch (e) {
      _handleError('markAsSeen', e);
    }
  }

  // ==========================================
  // ADVANCED MESSAGING & SERVICE IMPLEMENTATIONS
  // ==========================================

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'content': newText,
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
        'content': 'This message was deleted',
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

  Future<void> reactMessage(String chatId, String messageId, String userId, String emoji) async {
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
      _handleError('reactMessage', e);
    }
  }

  Future<void> replyMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String message,
    required String replyToMessageId,
  }) async {
    await sendMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      type: 'text',
      replyToMessageId: replyToMessageId,
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
    );
  }

  // ==========================================
  // MEDIA UPLOAD PLATFORMS
  // ==========================================

  Future<void> sendImage(String chatId, String senderId, String receiverId, String url) async {
    await sendMessage(chatId: chatId, senderId: senderId, receiverId: receiverId, message: url, type: 'image');
  }

  Future<void> sendVideo(String chatId, String senderId, String receiverId, String url) async {
    await sendMessage(chatId: chatId, senderId: senderId, receiverId: receiverId, message: url, type: 'video');
  }

  Future<void> sendDocument(String chatId, String senderId, String receiverId, String url, String fileName) async {
    await sendMessage(
      chatId: chatId, 
      senderId: senderId, 
      receiverId: receiverId, 
      message: url, 
      type: 'document',
      mediaMetaData: {'fileName': fileName},
    );
  }

  Future<void> sendAudio(String chatId, String senderId, String receiverId, String url) async {
    await sendMessage(chatId: chatId, senderId: senderId, receiverId: receiverId, message: url, type: 'audio');
  }

  Future<void> sendVoice(String chatId, String senderId, String receiverId, String url) async {
    await sendMessage(chatId: chatId, senderId: senderId, receiverId: receiverId, message: url, type: 'voice');
  }

  Future<void> sendLocation(String chatId, String senderId, String receiverId, double latitude, double longitude) async {
    await sendMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      message: '$latitude,$longitude',
      type: 'location',
      mediaMetaData: {'latitude': latitude, 'longitude': longitude},
    );
  }

  // ==========================================
  // GROUP CHAT LIFECYCLE & CORE LOGIC
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
        'lastMessageContent': 'Group created by administration',
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
  }) async {
    try {
      final messageRef = _firestore.collection('groups').doc(groupId).collection('messages').doc();
      
      await messageRef.set({
        'messageId': messageRef.id,
        'senderId': senderId,
        'receiverId': 'group',
        'content': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': type,
        'status': 'sent',
        'isDeletedForEveryone': false,
        'deletedForUsers': [],
        'starredBy': [],
        'reactions': {},
      });

      await _firestore.collection('groups').doc(groupId).update({
        'lastMessageContent': type == 'text' ? message : 'Media Attachment',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _handleError('sendGroupMessage', e);
    }
  }

  Stream<List<MessageModel>> getGroupMessagesStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => MessageModel.fromMap(doc.data())).toList();
    });
  }

  // ==========================================
  // PRIVATE ERROR HANDLING UTILITY
  // ==========================================

  void _handleError(String methodName, dynamic error) {
    print('[@ChatService] Error inside $methodName: $error');
  }
}
