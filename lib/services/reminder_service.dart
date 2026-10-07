import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> searchStudentById(String studentId) async {
    final cleanId = studentId.trim();
    if (cleanId.isEmpty) return null;

    try {
      var docSnapshot = await _firestore.collection('students').doc(cleanId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        _normalizeStudentData(data, docSnapshot.id);
        return data;
      }

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

      final userDoc = await _firestore.collection('users').doc(cleanId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        _normalizeStudentData(data, userDoc.id);
        return data;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  void _normalizeStudentData(Map<String, dynamic> data, String fallbackId) {
    if (data['uid'] == null || data['uid'].toString().isEmpty) {
      data['uid'] = fallbackId;
    }
    if (data['name'] == null || data['name'].toString().isEmpty) {
      data['name'] = data['displayName'] ?? data['fullName'] ?? 'No Name Provided';
    }
  }

  Future<void> sendPaymentReminder(ReminderModel reminder) async {
    final batch = _firestore.batch();

    final reminderRef = _firestore.collection('payment_reminders').doc(reminder.reminderId);

    final reminderData = reminder.toMap();
    reminderData['dayOfMonth'] = reminder.dueDate.day;
    reminderData['reminderHour'] = reminder.reminderTime.hour;
    reminderData['reminderMinute'] = reminder.reminderTime.minute;
    reminderData['isRecurring'] = true;
    reminderData['status'] = 'active';
    reminderData['createdAt'] = FieldValue.serverTimestamp();
    reminderData['lastSentAt'] = FieldValue.serverTimestamp();

    batch.set(reminderRef, reminderData, SetOptions(merge: true));

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
      'chatId': chatRoomId,
      'lastMessage': "Tuition fee reminder sent: ₹${reminder.amount.toStringAsFixed(0)}",
      'lastMessageTime': Timestamp.fromDate(reminder.reminderTime),
      'lastSenderId': reminder.teacherId,
      'participants': [reminder.teacherId, reminder.studentId],
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> deleteReminder(String reminderId) async {
    await _firestore.collection('payment_reminders').doc(reminderId).delete();
  }

  Stream<QuerySnapshot> getActiveReminders(String teacherId) {
    return _firestore
        .collection('payment_reminders')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots();
  }

  String _getChatRoomId(String user1, String user2) {
    return user1.compareTo(user2) <= 0 ? '${user1}_$user2' : '${user2}_$user1';
  }
}
