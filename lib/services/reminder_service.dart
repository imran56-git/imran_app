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

  Future<void> dispatchScheduledReminder(DocumentSnapshot reminderDoc) async {
    final data = reminderDoc.data() as Map<String, dynamic>;
    final String reminderId = reminderDoc.id;
    final String teacherId = (data['teacherId'] ?? '').toString();
    final String teacherName = (data['teacherName'] ?? 'Teacher').toString();
    final String studentId = (data['studentId'] ?? '').toString();
    final String studentName = (data['studentName'] ?? 'Student').toString();
    final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final String month = (data['month'] ?? 'Current Month').toString();
    final int day = (data['dayOfMonth'] as num?)?.toInt() ?? 10;

    if (studentId.isEmpty || teacherId.isEmpty) return;

    try {
      final feeQuery = await _firestore
          .collection('student_fees')
          .where('teacherId', isEqualTo: teacherId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      final batch = _firestore.batch();

      if (feeQuery.docs.isNotEmpty) {
        final existingDoc = feeQuery.docs.first;
        final feeData = existingDoc.data();
        final Map<String, dynamic> statuses =
            Map<String, dynamic>.from(feeData['monthStatuses'] ?? {});

        final String currentMonthStatus = statuses[month]?.toString() ?? 'NOT_ENROLLED';

        if (currentMonthStatus != 'DUE' && currentMonthStatus != 'PAID') {
          statuses[month] = 'DUE';
          final double currentTotalDue = (feeData['totalDue'] as num?)?.toDouble() ?? 0.0;
          final int currentDueCount = (feeData['dueMonthsCount'] as num?)?.toInt() ?? 0;

          final double newTotalDue = currentTotalDue + amount;
          final int newDueCount = currentDueCount + 1;

          batch.update(existingDoc.reference, {
            'monthStatuses': statuses,
            'totalDue': newTotalDue,
            'dueMonthsCount': newDueCount,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          final monthlyFeeRef = _firestore.collection('monthly_fee').doc(studentId);
          batch.set(monthlyFeeRef, {
            'studentId': studentId,
            'studentName': studentName,
            'teacherId': teacherId,
            'pendingAmount': newTotalDue,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        final newFeeRef = _firestore.collection('student_fees').doc();
        batch.set(newFeeRef, {
          'teacherId': teacherId,
          'studentId': studentId,
          'studentName': studentName,
          'subject': 'Tuition',
          'year': DateTime.now().year,
          'monthlyFee': amount,
          'monthStatuses': {month: 'DUE'},
          'dueMonthsCount': 1,
          'paidMonthsCount': 0,
          'totalPaid': 0.0,
          'totalDue': amount,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        final monthlyFeeRef = _firestore.collection('monthly_fee').doc(studentId);
        batch.set(monthlyFeeRef, {
          'studentId': studentId,
          'studentName': studentName,
          'teacherId': teacherId,
          'pendingAmount': amount,
          'totalPaid': 0.0,
          'monthlyFee': amount,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final reminderRef = _firestore.collection('payment_reminders').doc(reminderId);
      batch.update(reminderRef, {
        'status': 'sent',
        'lastSentAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      final String noticeMessage = "Hello $studentName,\n\n"
          "This is an official tuition fee notice on behalf of $teacherName.\n"
          "Tuition fee for $month is now due.\n\n"
          "Amount: ₹${amount.toStringAsFixed(0)}\n"
          "Due Day: $day of this month\n\n"
          "This fee has been recorded in your pending dues ledger.\nPlease clear your payment promptly.\n\n"
          "Thank you,\nFYBTT Official Desk";

      await sendOfficialNoticeToStudent(
        studentId: studentId,
        title: "Tuition Fee Due: ₹${amount.toStringAsFixed(0)} ($month)",
        messageContent: noticeMessage,
        category: 'tuition_fee',
      );
    } catch (_) {}
  }

  Future<int> checkAndProcessDueReminders({required String currentUserId}) async {
    if (currentUserId.isEmpty) return 0;
    final now = DateTime.now();
    int processedCount = 0;

    try {
      final teacherReminders = await _firestore
          .collection('payment_reminders')
          .where('teacherId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'scheduled')
          .get();

      for (var doc in teacherReminders.docs) {
        final data = doc.data();
        final Timestamp? scheduledFor = data['scheduledFor'] as Timestamp?;
        if (scheduledFor != null && scheduledFor.toDate().isBefore(now)) {
          await dispatchScheduledReminder(doc);
          processedCount++;
        }
      }

      final studentReminders = await _firestore
          .collection('payment_reminders')
          .where('studentId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'scheduled')
          .get();

      for (var doc in studentReminders.docs) {
        final data = doc.data();
        final Timestamp? scheduledFor = data['scheduledFor'] as Timestamp?;
        if (scheduledFor != null && scheduledFor.toDate().isBefore(now)) {
          await dispatchScheduledReminder(doc);
          processedCount++;
        }
      }
    } catch (_) {}

    return processedCount;
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
