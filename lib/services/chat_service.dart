import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // USER STATUS & TYPING INDICATORS (ROLE-AWARE)
  // ==========================================

  // বাগ ফিক্স: রোল অনুযায়ী ডেডিকেটেড কালেকশনে অনলাইন স্ট্যাটাস রিয়েল-টাইম সিঙ্ক
  Future<void> updateOnlineStatus(String userId, bool isOnline, bool isTeacher) async {
    try {
      final String collectionPath = isTeacher ? 'teachers' : 'students';
      
      // ১. নির্দিষ্ট রোল কালেকশন আপডেট
      await _firestore.collection(collectionPath).doc(userId).update({
        'isOnline': isOnline,
        'status': isOnline ? 'Online' : 'Offline',
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // ২. জেনারেলাইজড ইউজার লেজারে ব্যাকআপ আপডেট
      await _firestore.collection('users').doc(userId).update({
        'status': isOnline ? 'Online' : 'Offline',
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((_) {}); // ব্যাকআপ কালেকশন না থাকলেও ক্র্যাশ করবে না
      
    } catch (e) {
      _handleError('updateOnlineStatus', e);
    }
  }

  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping) async {
    try {
      await _firestore
          .collection('typing') // রিয়েল-টাইম পারফরম্যান্সের জন্য আলাদা রুট কালেকশন
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

  // ডিটারমিনিস্টিক চ্যাট রুম আইডি জেনারেটর (বাগ ২০ পারফরম্যান্স ফিক্স)
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
          'lastMessage': 'Chat initialized',
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
    required String type, // 'text', 'image', 'audio', 'document'
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
        'content': message, // content কি-ওয়ার্ড সিঙ্ক
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

      // চ্যাট হেডার রিয়াল-টাইম লস্ট মেসেজ মেটা আপডেট
      String previewText = message;
      if (type == 'image') previewText = '📷 Photo';
      if (type == 'audio' || type == 'voice') previewText = '🎵 Voice message';
      if (type == 'document') previewText = '📄 Document';

      batch.update(chatRef, {
        'lastMessage': previewText,
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
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      bool hasUnseen = false;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data['status'] != 'seen') {
          batch.update(doc.reference, {'status': 'seen'});
          hasUnseen = true;
        }
      }

      if (hasUnseen) {
        batch.update(_firestore.collection('chats').doc(chatId), {
          'unreadCount': 0, // চ্যাট ওপেন করলেই কাউন্টার রিসেট
        });
        await batch.commit();
      }
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

  // ==========================================
  // PRIVATE ERROR HANDLING UTILITY
  // ==========================================

  void _handleError(String methodName, dynamic error) {
    print('[@ChatService] Error inside $methodName: $error');
  }
}
