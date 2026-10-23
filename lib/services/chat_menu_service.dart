import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blocked_user_model.dart';
import '../models/report_model.dart';

class BlockStatus {
  final bool isBlockedByMe;
  final bool isBlockedByOther;

  const BlockStatus({
    required this.isBlockedByMe,
    required this.isBlockedByOther,
  });

  bool get isBlocked => isBlockedByMe || isBlockedByOther;
}

class ChatMenuService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _getChatRoomId(String user1, String user2) {
    final List<String> ids = [user1, user2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> blockUser(String currentUserId, String receiverId) async {
    try {
      String targetName = 'User';
      String targetPhoto = '';
      String targetRole = 'user';

      try {
        final tDoc =
            await _firestore.collection('teachers').doc(receiverId).get();
        if (tDoc.exists && tDoc.data() != null) {
          final data = tDoc.data()!;
          targetName = (data['fullName'] ?? data['name'] ?? 'Teacher').toString();
          targetPhoto = (data['profileImageUrl'] ?? data['profilePic'] ?? '').toString();
          targetRole = 'teacher';
        } else {
          final sDoc =
              await _firestore.collection('students').doc(receiverId).get();
          if (sDoc.exists && sDoc.data() != null) {
            final data = sDoc.data()!;
            targetName = (data['fullName'] ?? data['name'] ?? 'Student').toString();
            targetPhoto = (data['profileImageUrl'] ?? data['profilePic'] ?? '').toString();
            targetRole = 'student';
          } else {
            final uDoc =
                await _firestore.collection('users').doc(receiverId).get();
            if (uDoc.exists && uDoc.data() != null) {
              final data = uDoc.data()!;
              targetName = (data['fullName'] ?? data['name'] ?? 'User').toString();
              targetPhoto = (data['profileImageUrl'] ?? data['profilePic'] ?? '').toString();
              targetRole = (data['role'] ?? 'user').toString();
            }
          }
        }
      } catch (_) {}

      final blockedData = {
        'blockerId': currentUserId,
        'blockedId': receiverId,
        'name': targetName,
        'profilePic': targetPhoto,
        'role': targetRole,
        'timestamp': FieldValue.serverTimestamp(),
      };

      final batch = _firestore.batch();

      final blockRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(receiverId);
      batch.set(blockRef, blockedData);

      final String chatId = _getChatRoomId(currentUserId, receiverId);
      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.set(
        chatRef,
        {
          'blockedBy': FieldValue.arrayUnion([currentUserId]),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to block user: $e');
    }
  }

  Future<void> unblockUser(String currentUserId, String receiverId) async {
    try {
      final batch = _firestore.batch();

      final blockRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(receiverId);
      batch.delete(blockRef);

      final String chatId = _getChatRoomId(currentUserId, receiverId);
      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.set(
        chatRef,
        {
          'blockedBy': FieldValue.arrayRemove([currentUserId]),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to unblock user: $e');
    }
  }

  Future<bool> isUserBlocked(String currentUserId, String targetUserId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Stream<BlockStatus> getBlockStatusStream(
      String currentUserId, String targetUserId) {
    final myBlockStream = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked_users')
        .doc(targetUserId)
        .snapshots();

    final otherBlockStream = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('blocked_users')
        .doc(currentUserId)
        .snapshots();

    return myBlockStream.asyncMap((mySnap) async {
      final otherSnap = await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('blocked_users')
          .doc(currentUserId)
          .get();

      return BlockStatus(
        isBlockedByMe: mySnap.exists,
        isBlockedByOther: otherSnap.exists,
      );
    }).handleError((_) {
      return const BlockStatus(isBlockedByMe: false, isBlockedByOther: false);
    });
  }

  Stream<List<Map<String, dynamic>>> getBlockedUsersStream(
      String currentUserId) {
    if (currentUserId.trim().isEmpty) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked_users')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();
    }).handleError((_) => <Map<String, dynamic>>[]);
  }

  Future<void> reportUser(
      String currentUserId, String receiverId, String reason) async {
    try {
      final report = ReportModel(
        reporterId: currentUserId,
        reportedUserId: receiverId,
        reason: reason,
        timestamp: DateTime.now(),
      );
      await _firestore.collection('reports').add(report.toMap());
    } catch (e) {
      throw Exception('Failed to report user: $e');
    }
  }

  Future<void> clearChat(String chatRoomId) async {
    try {
      final messagesQuery = await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .get();

      final docs = messagesQuery.docs;
      if (docs.isEmpty) return;

      const chunkSize = 450;
      for (var i = 0; i < docs.length; i += chunkSize) {
        final chunk = docs.sublist(
          i,
          i + chunkSize > docs.length ? docs.length : i + chunkSize,
        );
        final WriteBatch batch = _firestore.batch();
        for (var doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      await _firestore.collection('chats').doc(chatRoomId).update({
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to clear chat: $e');
    }
  }

  Future<void> deleteConversation(String chatRoomId) async {
    try {
      await clearChat(chatRoomId);
      await _firestore.collection('chats').doc(chatRoomId).delete();
    } catch (e) {
      throw Exception('Failed to delete conversation: $e');
    }
  }
}
