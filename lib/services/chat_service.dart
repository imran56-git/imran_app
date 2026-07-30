import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<Map<String, dynamic>?> getUserProfile(String userId, bool isTeacher) async {
    try {
      final String collectionPath = isTeacher ? 'teachers' : 'students';
      final doc = await _firestore.collection(collectionPath).doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
      
      // Fallback: Check 'users' collection if not found in specific role collection
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data();
    } catch (e) {
      _handleError('getUserProfile', e);
      return null;
    }
  }

  Stream<QuerySnapshot> getUserChatsStream(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots(includeMetadataChanges: true) // 👈 Realtime Multi-device Sync Fix
        .handleError((error) {
      _handleError('getUserChatsStream', error);
    });
  }

  Future<void> updateOnlineStatus(String userId, bool isOnline, bool isTeacher) async {
    try {
      final String collectionPath = isTeacher ? 'teachers' : 'students';

      await _firestore.collection(collectionPath).doc(userId).update({
        'isOnline': isOnline,
        'status': isOnline ? 'Online' : 'Offline',
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((_) {});

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
      await _firestore.collection('typing').doc(chatId).set({
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
    }).handleError((error) {
      _handleError('getUserStatusStream', error);
    });
  }

  // 🔴 FIX 1: Alphabetical Sorting to ensure EXACT SAME Chat Room ID across all devices
  String getChatRoomId(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort(); // সবসময় Alphabetically Sort করবে
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
        'participants': [teacherId, studentId],
        'isGroup': false,
      };

      // Real Name & Profile Image আপডেট রাখা
      if (teacherName.isNotEmpty && teacherName != 'Me' && teacherName != 'User') {
        updateData['teacherName'] = teacherName;
      }
      if (studentName.isNotEmpty && studentName != 'Me' && studentName != 'User') {
        updateData['studentName'] = studentName;
      }
      if (teacherImage.isNotEmpty) updateData['teacherImage'] = teacherImage;
      if (studentImage.isNotEmpty) updateData['studentImage'] = studentImage;

      if (!doc.exists) {
        updateData['lastMessageContent'] = 'Chat initialized';
        updateData['lastMessageTime'] = FieldValue.serverTimestamp();
        updateData['unreadCount'] = 0;
        updateData['unreadFor'] = ''; 
        updateData['pinnedBy'] = [];
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
      
      // 🔴 FIX 2: chatId পুনরায় ভ্যালিডেশান সহ ফিক্স করা
      final String correctChatId = getChatRoomId(senderId, receiverId);
      final chatRef = _firestore.collection('chats').doc(correctChatId);
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

      // Unread Count ফেচ লজিক
      final chatDoc = await chatRef.get();
      int currentUnread = 0;
      String currentUnreadFor = '';

      if (chatDoc.exists) {
        final data = chatDoc.data();
        currentUnreadFor = data?['unreadFor'] ?? '';
        if (currentUnreadFor == receiverId) {
          currentUnread = (data?['unreadCount'] ?? 0) as int;
        }
      }

      batch.set(chatRef, {
        'chatId': correctChatId,
        'lastMessageContent': previewText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
        'unreadCount': currentUnread + 1,
        'unreadFor': receiverId,
        'participants': [senderId, receiverId], // Array নিশ্চিত করা
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      _handleError('sendMessage', e);
      throw Exception('Failed to send message: $e');
    }
  }

  Future<void> markAsSeen(String chatId, String currentUserId) async {
    try {
      final querySnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'sent')
          .get();

      final batch = _firestore.batch();

      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'status': 'seen'});
      }

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (chatDoc.exists) {
        final unreadFor = chatDoc.data()?['unreadFor'];
        if (unreadFor == currentUserId) {
          batch.set(_firestore.collection('chats').doc(chatId), {
            'unreadCount': 0,
            'unreadFor': '',
          }, SetOptions(merge: true));
        }
      }

      await batch.commit();
    } catch (e) {
      _handleError('markAsSeen', e);
    }
  }

  // --- File Upload Helpers ---

  Future<String> _uploadFileToStorage(File file, String folder) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
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
  }) async {
    final url = await _uploadFileToStorage(file, 'images');
    await sendMessage(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      message: url,
      type: 'image',
    );
  }

  Future<void> sendVideoFile({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required File file,
  }) async {
    final url = await _uploadFileToStorage(file, 'videos');
    await sendMessage(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      message: url,
      type: 'video',
    );
  }

  Future<void> sendDocumentFile({
    required String chatRoomId,
    required String senderId,
    required String receiverId,
    required File file,
    required String fileName,
  }) async {
    final url = await _uploadFileToStorage(file, 'documents');
    await sendMessage(
      chatId: chatRoomId,
      senderId: senderId,
      receiverId: receiverId,
      message: url,
      type: 'document',
      mediaMetaData: {'fileName': fileName},
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

  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String message,
    required String type,
    String? replyToMessageId,
    String? replyToText,
  }) async {
    try {
      final messageRef = _firestore.collection('groups').doc(groupId).collection('messages').doc();

      final Map<String, dynamic> messageData = {
        'messageId': messageRef.id,
        'senderId': senderId,
        'content': message,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'replyToMessageId': replyToMessageId,
        'replyToText': replyToText,
      };

      await messageRef.set(messageData);

      await _firestore.collection('groups').doc(groupId).update({
        'lastMessage': message,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _handleError('sendGroupMessage', e);
      throw Exception('Failed to send group message: $e');
    }
  }

  // 🔴 FIX 3: includeMetadataChanges: true দিয়ে Realtime Stream নিশ্চিত করা
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true) 
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['messageId'] = doc.id;
        return MessageModel.fromMap(data);
      }).toList();
    }).handleError((error) {
      _handleError('getMessages (Stream Error)', error);
    });
  }

  Stream<List<MessageModel>> getGroupMessagesStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['messageId'] = doc.id;
        return MessageModel.fromMap(data);
      }).toList();
    }).handleError((error) {
      _handleError('getGroupMessagesStream (Stream Error)', error);
    });
  }

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
          .set({
        'reactions': {userId: emoji}
      }, SetOptions(merge: true));
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

  void _handleError(String methodName, dynamic error) {
    log('🔴 [@ChatService] Error inside $methodName: $error');
  }
}
