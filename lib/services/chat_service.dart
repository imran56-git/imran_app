import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // আপডেট অনলাইন স্ট্যাটাস
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    await _firestore.collection('users').doc(userId).update({
      'status': isOnline ? 'Online' : 'Last seen',
      'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
    });
  }

  // আপডেট টাইপিং স্ট্যাটাস
  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping) async {
    await _firestore.collection('chats').doc(chatId).collection('typing').doc(userId).set({
      'typing': isTyping,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // স্ট্রিমে অনলাইন বা লাস্ট সিন শুনে নেওয়া
  Stream<Map<String, dynamic>> getUserStatusStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      final data = doc.data();
      return {
        'status': data?['status'] ?? 'Offline',
        'lastSeen': data?['lastSeen'],
      };
    });
  }

  // স্ট্রিমে টাইপিং স্ট্যাটাস শুনে নেওয়া
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