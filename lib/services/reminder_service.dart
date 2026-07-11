import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> searchStudentById(String studentId) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('uid', isEqualTo: studentId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data();
    }
    return null;
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
    return user1.hashCode <= user2.hashCode ? '${user1}_$user2' : '${user2}_$user1';
  }
}
