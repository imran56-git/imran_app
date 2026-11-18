import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reminder_model.dart';

class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String officialSenderId = 'OFFICIAL_FYBTT_DESK';
  static const String officialSenderName = 'FYBTT official';
  static const String officialLogoAsset = 'assets/images/app_logo.png';
  static const String verifiedBadgeAsset = 'assets/images/Verified_Batch.png';

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static final Set<String> _processingReminderIds = <String>{};

  Future<Map<String, dynamic>?> searchStudentById(String studentId) async {
    final cleanId = studentId.trim();
    if (cleanId.isEmpty) return null;

    try {
      final docSnapshot =
          await _firestore.collection('students').doc(cleanId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = Map<String, dynamic>.from(docSnapshot.data()!);
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
        final data = Map<String, dynamic>.from(doc.data());
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
        final data = Map<String, dynamic>.from(doc.data());
        _normalizeStudentData(data, doc.id);
        return data;
      }

      final userDoc = await _firestore.collection('users').doc(cleanId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = Map<String, dynamic>.from(userDoc.data()!);
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

  String _normalizeMonthName(dynamic rawMonth, DateTime fallbackDate) {
    final cleaned = (rawMonth ?? '').toString().trim().toLowerCase();
    if (cleaned.isNotEmpty && cleaned != 'current month') {
      for (final m in _monthNames) {
        if (m.toLowerCase() == cleaned) return m;
      }
      if (cleaned.length >= 3) {
        for (final m in _monthNames) {
          if (m.toLowerCase().startsWith(cleaned.substring(0, 3))) return m;
        }
      }
    }
    return _monthNames[fallbackDate.month - 1];
  }

  Future<bool> hasActiveReminder({
    required String teacherId,
    required String studentId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('payment_reminders')
          .where('teacherId', isEqualTo: teacherId)
          .where('studentId', isEqualTo: studentId)
          .get();

      return querySnapshot.docs.any((doc) {
        final status = (doc.data()['status'] ?? '').toString().toLowerCase();
        return status == 'scheduled' ||
            status == 'active' ||
            status == 'sent' ||
            status == 'pending';
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> sendPaymentReminder(ReminderModel reminder) async {
    final bool duplicateExists = await hasActiveReminder(
      teacherId: reminder.teacherId,
      studentId: reminder.studentId,
    );

    if (duplicateExists) {
      throw Exception('An active reminder already exists for this student.');
    }

    final reminderRef =
        _firestore.collection('payment_reminders').doc(reminder.reminderId);

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
      'messageCategory': 'fee_reminder',
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

    batch.set(
      chatRef,
      {
        'chatId': officialChatId,
        'teacherId': officialSenderId,
        'studentId': studentId,
        'teacherName': officialSenderName,
        'teacherImage': officialLogoAsset,
        'isOfficial': true,
        'isVerified': true,
        'verifiedBadge': verifiedBadgeAsset,
        'isGroup': false,
        'chatCategory': 'official_fees',
        'lastMessage': title,
        'lastMessageContent': messageContent,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': officialSenderId,
        'unreadCount': FieldValue.increment(1),
        'unreadCount_$studentId': FieldValue.increment(1),
        'unreadFor': studentId,
        'deletedBy': FieldValue.arrayRemove([studentId]),
        'participants': [officialSenderId, studentId],
      },
      SetOptions(merge: true),
    );

    final notificationRef = _firestore.collection('notifications').doc();
    batch.set(notificationRef, {
      'notificationId': notificationRef.id,
      'senderId': officialSenderId,
      'senderName': officialSenderName,
      'senderPhotoUrl': officialLogoAsset,
      'chatId': officialChatId,
      'isOfficial': true,
      'isVerified': true,
      'verifiedBadge': verifiedBadgeAsset,
      'receiverId': studentId,
      'title': title,
      'body': messageContent,
      'message': messageContent,
      'type': 'official_fee_reminder',
      'status': 'pending',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> dispatchScheduledReminder(DocumentSnapshot reminderDoc) async {
    final rawData = reminderDoc.data();
    if (rawData is! Map<String, dynamic>) return;
    final data = rawData;

    final String reminderId = reminderDoc.id;
    final String teacherId = (data['teacherId'] ?? '').toString().trim();
    final String teacherName =
        (data['teacherName'] ?? 'Teacher').toString().trim();
    final String studentId = (data['studentId'] ?? '').toString().trim();
    final String studentName =
        (data['studentName'] ?? 'Student').toString().trim();
    final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final rawScheduled = data['scheduledFor'];
    final DateTime referenceDate =
        rawScheduled is Timestamp ? rawScheduled.toDate() : DateTime.now();
    final String month = _normalizeMonthName(data['month'], referenceDate);
    final int day = (data['dayOfMonth'] as num?)?.toInt() ?? referenceDate.day;
    final int targetYear = referenceDate.year;

    if (studentId.isEmpty || teacherId.isEmpty) return;

    try {
      final feeQuery = await _firestore
          .collection('student_fees')
          .where('teacherId', isEqualTo: teacherId)
          .where('studentId', isEqualTo: studentId)
          .get();

      final batch = _firestore.batch();
      final int monthNumber = _monthNames.indexOf(month) + 1;
      final String dueDateFormatted =
          '${day.toString().padLeft(2, '0')}/${monthNumber.toString().padLeft(2, '0')}/$targetYear';

      if (feeQuery.docs.isNotEmpty) {
        final existingDoc = feeQuery.docs.firstWhere(
          (d) => (d.data()['year'] as num?)?.toInt() == targetYear,
          orElse: () => feeQuery.docs.first,
        );
        final feeData = existingDoc.data();
        final Map<String, dynamic> statuses = Map<String, dynamic>.from(
          (feeData['monthStatuses'] as Map?) ??
              (feeData['monthlyStatus'] as Map?) ??
              <String, dynamic>{},
        );

        final String existingMonthKey = statuses.keys.firstWhere(
          (k) => k.trim().toLowerCase() == month.toLowerCase(),
          orElse: () => month,
        );

        final String currentMonthStatus =
            (statuses[existingMonthKey] ?? 'NOT_ENROLLED')
                .toString()
                .trim()
                .toUpperCase();

        if (currentMonthStatus != 'PAID') {
          statuses[existingMonthKey] = 'DUE';

          final existingEntrySnap = await existingDoc.reference
              .collection('fee_entries')
              .where('month', isEqualTo: month)
              .limit(1)
              .get();

          if (existingEntrySnap.docs.isNotEmpty) {
            final entryDoc = existingEntrySnap.docs.first;
            final entryStatus = (entryDoc.data()['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            if (entryStatus != 'paid') {
              batch.update(entryDoc.reference, {
                'month': month,
                'dueDate': dueDateFormatted,
                'amount': amount,
                'status': 'due',
                'source': 'manual_fee_reminder',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          } else {
            final entryRef =
                existingDoc.reference.collection('fee_entries').doc();
            batch.set(entryRef, {
              'entryId': entryRef.id,
              'month': month,
              'dueDate': dueDateFormatted,
              'amount': amount,
              'status': 'due',
              'source': 'manual_fee_reminder',
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          final double existingMonthlyFee =
              (feeData['monthlyFee'] as num?)?.toDouble() ?? 0.0;
          final double unitFee =
              existingMonthlyFee > 0 ? existingMonthlyFee : amount;

          int newDueCount = 0;
          int newPaidCount = 0;
          for (final val in statuses.values) {
            final normalized = val.toString().trim().toUpperCase();
            if (normalized == 'DUE' || normalized == 'PENDING') {
              newDueCount++;
            } else if (normalized == 'PAID') {
              newPaidCount++;
            }
          }

          final double newTotalDue = newDueCount * unitFee;
          final double newTotalPaid = newPaidCount * unitFee;

          batch.update(existingDoc.reference, {
            'monthStatuses': statuses,
            'totalDue': newTotalDue,
            'totalPaid': newTotalPaid,
            'totalCollected': newTotalPaid,
            'dueMonthsCount': newDueCount,
            'paidMonthsCount': newPaidCount,
            'lastReminderMonth': month,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          final monthlyFeeRef =
              _firestore.collection('monthly_fee').doc(studentId);
          batch.set(
            monthlyFeeRef,
            {
              'studentId': studentId,
              'studentName': studentName,
              'teacherId': teacherId,
              'pendingAmount': newTotalDue,
              'totalPaid': newTotalPaid,
              'lastUpdated': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      } else {
        final newFeeRef = _firestore.collection('student_fees').doc();
        final Map<String, dynamic> initialStatuses = {month: 'DUE'};

        batch.set(newFeeRef, {
          'teacherId': teacherId,
          'studentId': studentId,
          'studentName': studentName,
          'subject': 'Tuition',
          'year': targetYear,
          'monthlyFee': amount,
          'monthStatuses': initialStatuses,
          'dueMonthsCount': 1,
          'paidMonthsCount': 0,
          'totalPaid': 0.0,
          'totalCollected': 0.0,
          'totalDue': amount,
          'lastReminderMonth': month,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        final entryRef = newFeeRef.collection('fee_entries').doc();
        batch.set(entryRef, {
          'entryId': entryRef.id,
          'month': month,
          'dueDate': dueDateFormatted,
          'amount': amount,
          'status': 'due',
          'source': 'manual_fee_reminder',
          'createdAt': FieldValue.serverTimestamp(),
        });

        final monthlyFeeRef =
            _firestore.collection('monthly_fee').doc(studentId);
        batch.set(
          monthlyFeeRef,
          {
            'studentId': studentId,
            'studentName': studentName,
            'teacherId': teacherId,
            'pendingAmount': amount,
            'totalPaid': 0.0,
            'monthlyFee': amount,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      final reminderRef =
          _firestore.collection('payment_reminders').doc(reminderId);
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

  Future<int> checkAndProcessDueReminders({
    required String currentUserId,
  }) async {
    if (currentUserId.isEmpty) return 0;
    final now = DateTime.now();
    int processedCount = 0;

    try {
      final teacherReminders = await _firestore
          .collection('payment_reminders')
          .where('teacherId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'scheduled')
          .get();

      final studentReminders = await _firestore
          .collection('payment_reminders')
          .where('studentId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'scheduled')
          .get();

      final Map<String, QueryDocumentSnapshot> uniqueDocs = {};
      for (final doc in teacherReminders.docs) {
        uniqueDocs[doc.id] = doc;
      }
      for (final doc in studentReminders.docs) {
        uniqueDocs[doc.id] = doc;
      }

      for (final doc in uniqueDocs.values) {
        if (_processingReminderIds.contains(doc.id)) continue;
        final data = doc.data() as Map<String, dynamic>?;
        final Timestamp? scheduledFor = data?['scheduledFor'] as Timestamp?;
        if (scheduledFor != null && !scheduledFor.toDate().isAfter(now)) {
          _processingReminderIds.add(doc.id);
          try {
            await dispatchScheduledReminder(doc);
            processedCount++;
          } finally {
            _processingReminderIds.remove(doc.id);
          }
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