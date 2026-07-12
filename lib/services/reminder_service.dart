import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // বাগ ১৫ ফিক্স: সরাসরি 'students' কালেকশন থেকে নিখুঁত ডেটা এবং নাম রিড করা
  Future<Map<String, dynamic>?> searchStudentById(String studentId) async {
    try {
      final docSnapshot = await _firestore.collection('students').doc(studentId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        // যদি ডকুমেন্টের ভেতর ভুলবশত 'uid' ফিল্ড না থাকে, তবে ডক আইডি সেট করে দেওয়া
        if (data['uid'] == null) {
          data['uid'] = docSnapshot.id;
        }
        // নাম ফিল্ডের ডাবল ব্যাকআপ চেক
        if (data['name'] == null) {
          data['name'] = data['displayName'] ?? 'No Name Provided';
        }
        return data;
      }
      return null;
    } catch (e) {
      // কনসোলে এরর প্রপারলি লগ করা
      intlLog("Error in searchStudentById: $e");
      return null;
    }
  }

  Future<void> sendPaymentReminder(ReminderModel reminder) async {
    final batch = _firestore.batch();

    // ১. payment_reminders কালেকশনে নোটিফিকেশন এন্ট্রি সেভ
    final reminderRef = _firestore.collection('payment_reminders').doc(reminder.reminderId);
    batch.set(reminderRef, reminder.toMap());

    // ২. ডিটারমিনিস্টিক আইডি জেনারেশন মেথড কল
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

    // ৩. চ্যাট রুমের মেটাডেটা রিয়াল-টাইম আপডেট
    final chatRef = _firestore.collection('chats').doc(chatRoomId);
    batch.set(chatRef, {
      'lastMessage': "Tuition fee reminder sent.",
      'lastMessageTime': Timestamp.fromDate(reminder.reminderTime),
      'participants': [reminder.teacherId, reminder.studentId],
    }, SetOptions(merge: true));

    // ব্যাচ অপারেশন এক্সিকিউট করা
    await batch.commit();
  }

  // বাগ ২০ ফিক্স: রানটাইম মেমোরি লিক এবং আইডি মিসম্যাচ রোধে প্রফেশনাল অ্যালফাবেটিক্যাল কম্পেয়ার
  String _getChatRoomId(String user1, String user2) {
    return user1.compareTo(user2) <= 0 ? '${user1}_$user2' : '${user2}_$user1';
  }

  // ডিবাগিং ট্র্যাকার
  void intlLog(String msg) {
    print("[ReminderService] $msg");
  }
}
