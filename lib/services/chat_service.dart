import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    await _firestore.collection('users').doc(userId).update({
      'status': isOnline ? 'Online' : 'Last seen',
      'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping) async {
    await _firestore.collection('chats').doc(chatId).collection('typing').doc(userId).set({
      'typing': isTyping,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<Map<String, dynamic>> getUserStatusStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      return {
        'status': data?['status'] ?? 'Offline',
        'lastSeen': data?['lastSeen'],
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
        .map((doc) => doc.data()?['typing'] ?? false);
  }
}