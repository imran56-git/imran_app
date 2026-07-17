import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> searchStudentById(String studentId) async {
    // যেকোনো স্পেস রিমুভ করার জন্য ট্রিম করে নেওয়া হলো
    final cleanId = studentId.trim();
    if (cleanId.isEmpty) return null;

    try {
      // ১. প্রথমে সরাসরি Document ID (ডকুমেন্ট নাম) দিয়ে খোঁজার চেষ্টা করবে
      var docSnapshot = await _firestore.collection('students').doc(cleanId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        _normalizeStudentData(data, docSnapshot.id);
        return data;
      }

      // ২. যদি সরাসরি না পাওয়া যায়, তবে ডকুমেন্টের ভেতরের 'uid' ফিল্ড কুয়েরি করবে
      final querySnapshot = await _firestore
          .collection('students')
          .where('uid', isEqualTo: cleanId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        _normalizeStudentData(data, doc.id);
        return data;
      }

      // ৩. সবশেষে ব্যাকআপ হিসেবে 'studentId' ফিল্ড দিয়েও চেক করে নেওয়া নিরাপদ
      final backupQuery = await _firestore
          .collection('students')
          .where('studentId', isEqualTo: cleanId)
          .limit(1)
          .get();

      if (backupQuery.docs.isNotEmpty) {
        final doc = backupQuery.docs.first;
        final data = doc.data();
        _normalizeStudentData(data, doc.id);
        return data;
      }

      return null;
    } catch (e) {
      intlLog("Error in searchStudentById: $e");
      return null;
    }
  }

  /// ডেটার ফিল্ডগুলোকে স্ট্যান্ডার্ড ফরম্যাটে রূপান্তর করার হেল্পার মেথড
  void _normalizeStudentData(Map<String, dynamic> data, String fallbackId) {
    if (data['uid'] == null) {
      data['uid'] = fallbackId;
    }
    if (data['name'] == null) {
      data['name'] = data['displayName'] ?? data['fullName'] ?? 'No Name Provided';
    }
  }

  Future<void> sendPaymentReminder(ReminderModel reminder) async {
    final batch = _firestore.batch();

    final reminderRef = _firestore.collection('payment_reminders').doc(reminder.reminderId);
    batch.set(reminderRef, reminder.toMap());

    final String chatRoomId = _getChatRoomId(reminder.teacherId, reminder.studentId);
    final messageRef = _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(reminder.reminderId);

    final String formattedMessage = "Hello ${reminder.studentName},\n\n"
        "This is a friendly reminder from ${reminder.teacherName}.\n"
        "Your tuition fee for ${reminder.month} is now due.\n\n"
        "Amount: ₹${reminder.amount.toStringAsFixed(0)}\n"
        "Due Date: ${reminder.dueDate.day}/${reminder.dueDate.month}/${reminder.dueDate.year}\n\n"
        "Please complete the payment at your earliest convenience.\n"
        "Thank you.";

    batch.set(messageRef, {
      'messageId': reminder.reminderId,
      'senderId': reminder.teacherId,
      'receiverId': reminder.studentId,
      'content': formattedMessage,
      'type': 'text',
      'status': 'sent',
      'timestamp': Timestamp.fromDate(reminder.reminderTime),
    });

    final chatRef = _firestore.collection('chats').doc(chatRoomId);
    batch.set(chatRef, {
      'lastMessage': "Tuition fee reminder sent.",
      'lastMessageTime': Timestamp.fromDate(reminder.reminderTime),
      'participants': [reminder.teacherId, reminder.studentId],
    }, SetOptions(merge: true));

    await batch.commit();
  }

  String _getChatRoomId(String user1, String user2) {
    return user1.compareTo(user2) <= 0 ? '${user1}_$user2' : '${user2}_$user1';
  }

  void intlLog(String msg) {
    print("[ReminderService] $msg");
  }
}
