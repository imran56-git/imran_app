import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blocked_user_model.dart';
import '../models/report_model.dart';

class ChatMenuService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Block User
  Future<void> blockUser(String currentUserId, String receiverId) async {
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
  }

  // 2. Report User
  Future<void> reportUser(String currentUserId, String receiverId, String reason) async {
    final report = ReportModel(
      reporterId: currentUserId,
      reportedUserId: receiverId,
      reason: reason,
      timestamp: DateTime.now(),
    );
    await _firestore.collection('reports').add(report.toMap());
  }

  // 3. Clear Chat Messages
  Future<void> clearChat(String chatRoomId) async {
    final messagesQuery = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .get();

    WriteBatch batch = _firestore.batch();
    for (var doc in messagesQuery.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // 4. Delete Conversation
  Future<void> deleteConversation(String chatRoomId) async {
    await clearChat(chatRoomId);
    await _firestore.collection('chat_rooms').doc(chatRoomId).delete();
  }
}
