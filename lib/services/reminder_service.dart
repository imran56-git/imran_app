import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String officialSenderId = 'OFFICIAL_FYBTT_DESK';
  static const String officialSenderName = 'FYBTT official';
  static const String officialLogoAsset = 'assets/images/app_logo.png';
  static const String verifiedBadgeAsset = 'assets/images/Verified_Batch.png';

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
    } catch (_) {
      return null;
    }
  }

  void _normalizeStudentData(Map<String, dynamic> data, String fallbackId) {
    if (data['uid'] == null || data['uid'].toString().isEmpty) {
      data['uid'] = fallbackId;
    }
    if (data['name'] == null || data['name'].toString().isEmpty) {
      data['name'] = data['displayName'] ?? data['fullName'] ?? 'Student';
    }
  }

  Future<void> sendPaymentReminder(ReminderModel reminder) async {
    final reminderRef = _firestore.collection('payment_reminders').doc(reminder.reminderId);

    final reminderData = reminder.toMap();
    reminderData['dayOfMonth'] = reminder.dueDate.day;
    reminderData['reminderHour'] = reminder.reminderTime.hour;
    reminderData['reminderMinute'] = reminder.reminderTime.minute;
    reminderData['isRecurring'] = true;
    reminderData['status'] = 'scheduled';
    reminderData['scheduledFor'] = Timestamp.fromDate(reminder.reminderTime);
    reminderData['createdAt'] = FieldValue.serverTimestamp();
    reminderData['lastSentAt'] = null;

    await reminderRef.set(reminderData, SetOptions(merge: true));
  }

  Future<void> sendOfficialNoticeToStudent({
    required String studentId,
    required String title,
    required String messageContent,
    String? category,
  }) async {
    final batch = _firestore.batch();
    final String officialChatId = 'official_desk_$studentId';
    final chatRef = _firestore.collection('chats').doc(officialChatId);
    final messageRef = chatRef.collection('messages').doc();

    final messageData = {
      'messageId': messageRef.id,
      'senderId': officialSenderId,
      'senderName': officialSenderName,
      'senderPhoto': officialLogoAsset,
      'receiverId': studentId,
      'content': messageContent,
      'type': 'official_notice',
      'category': category ?? 'tuition_fee',
      'title': title,
      'isOfficial': true,
      'isVerified': true,
      'verifiedBadge': verifiedBadgeAsset,
      'status': 'sent',
      'timestamp': FieldValue.serverTimestamp(),
      'isDeletedForEveryone': false,
      'deletedForUsers': [],
    };

    batch.set(messageRef, messageData);

    batch.set(chatRef, {
      'chatId': officialChatId,
      'teacherId': officialSenderId,
      'studentId': studentId,
      'teacherName': officialSenderName,
      'teacherImage': officialLogoAsset,
      'isOfficial': true,
      'isVerified': true,
      'verifiedBadge': verifiedBadgeAsset,
      'isGroup': false,
      'lastMessage': title,
      'lastMessageContent': messageContent,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': officialSenderId,
      'unreadCount': FieldValue.increment(1),
      'unreadFor': studentId,
      'participants': [officialSenderId, studentId],
    }, SetOptions(merge: true));

    final notificationRef = _firestore.collection('notifications').doc();
    batch.set(notificationRef, {
      'notificationId': notificationRef.id,
      'senderId': officialSenderId,
      'senderName': officialSenderName,
      'senderPhotoUrl': officialLogoAsset,
      'isOfficial': true,
      'isVerified': true,
      'verifiedBadge': verifiedBadgeAsset,
      'receiverId': studentId,
      'title': title,
      'message': messageContent,
      'type': 'official_notice',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

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
}
