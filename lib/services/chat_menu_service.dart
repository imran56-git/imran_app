import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blocked_user_model.dart';
import '../models/report_model.dart';

class ChatMenuService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Block User
  Future<void> blockUser(String currentUserId, String receiverId) async {
    try {
      final blockedUser = BlockedUserModel(
        blockerId: currentUserId,
        blockedId: receiverId,
        timestamp: DateTime.now(),
      );
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(receiverId)
          .set(blockedUser.toMap());
    } catch (e) {
      throw Exception('Failed to block user: $e');
    }
  }

  // 2. Unblock User
  Future<void> unblockUser(String currentUserId, String receiverId) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(receiverId)
          .delete();
    } catch (e) {
      throw Exception('Failed to unblock user: $e');
    }
  }

  // 3. Check Block Status
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

  // 4. Report User
  Future<void> reportUser(String currentUserId, String receiverId, String reason) async {
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

  // 5. Clear Chat Messages Safely (Chunked Batch Deletion for 500+ items)
  Future<void> clearChat(String chatRoomId) async {
    try {
      final messagesQuery = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .get();

      final docs = messagesQuery.docs;
      if (docs.isEmpty) return;

      // Firestore Batch limit is 500 actions
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

      // Reset last message info in chat room document
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to clear chat: $e');
    }
  }

  // 6. Delete Conversation
  Future<void> deleteConversation(String chatRoomId) async {
    try {
      await clearChat(chatRoomId);
      await _firestore.collection('chat_rooms').doc(chatRoomId).delete();
    } catch (e) {
      throw Exception('Failed to delete conversation: $e');
    }
  }
}
