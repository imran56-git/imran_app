import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  final String reminderId;
  final String studentName;
  final String studentId;
  final String teacherId;
  final String teacherName;
  final double amount;
  final String month;
  final DateTime dueDate;
  final DateTime reminderTime;
  final String status;
  final int dayOfMonth;
  final int reminderHour;
  final int reminderMinute;
  final bool isRecurring;
  final DateTime? scheduledFor;
  final DateTime? lastSentAt;
  final DateTime? createdAt;

  ReminderModel({
    required this.reminderId,
    required this.studentName,
    required this.studentId,
    required this.teacherId,
    required this.teacherName,
    required this.amount,
    required this.month,
    required this.dueDate,
    required this.reminderTime,
    required this.status,
    int? dayOfMonth,
    int? reminderHour,
    int? reminderMinute,
    this.isRecurring = true,
    DateTime? scheduledFor,
    this.lastSentAt,
    this.createdAt,
  })  : dayOfMonth = dayOfMonth ?? dueDate.day,
        reminderHour = reminderHour ?? reminderTime.hour,
        reminderMinute = reminderMinute ?? reminderTime.minute,
        scheduledFor = scheduledFor ?? reminderTime;

  Map<String, dynamic> toMap() {
    return {
      'reminderId': reminderId,
      'studentName': studentName,
      'studentId': studentId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'amount': amount,
      'month': month,
      'dueDate': Timestamp.fromDate(dueDate),
      'reminderTime': Timestamp.fromDate(reminderTime),
      'status': status,
      'dayOfMonth': dayOfMonth,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'isRecurring': isRecurring,
      'scheduledFor': scheduledFor != null
          ? Timestamp.fromDate(scheduledFor!)
          : Timestamp.fromDate(reminderTime),
      'lastSentAt': lastSentAt != null ? Timestamp.fromDate(lastSentAt!) : null,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final dueDateParsed = parseDate(map['dueDate']);
    final reminderTimeParsed = parseDate(map['reminderTime']);

    DateTime? scheduledForParsed;
    if (map['scheduledFor'] != null) {
      scheduledForParsed = parseDate(map['scheduledFor']);
    } else {
      scheduledForParsed = reminderTimeParsed;
    }

    DateTime? lastSentAtParsed;
    if (map['lastSentAt'] != null) {
      lastSentAtParsed = parseDate(map['lastSentAt']);
    }

    DateTime? createdAtParsed;
    if (map['createdAt'] != null) {
      createdAtParsed = parseDate(map['createdAt']);
    }

    return ReminderModel(
      reminderId: map['reminderId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? 'Student',
      studentId: map['studentId']?.toString() ?? '',
      teacherId: map['teacherId']?.toString() ?? '',
      teacherName: map['teacherName']?.toString() ?? 'Teacher',
      amount: map['amount'] is num
          ? (map['amount'] as num).toDouble()
          : (double.tryParse(map['amount']?.toString() ?? '0.0') ?? 0.0),
      month: map['month']?.toString() ?? '',
      dueDate: dueDateParsed,
      reminderTime: reminderTimeParsed,
      status: map['status']?.toString() ?? 'scheduled',
      dayOfMonth: (map['dayOfMonth'] as num?)?.toInt() ?? dueDateParsed.day,
      reminderHour: (map['reminderHour'] as num?)?.toInt() ?? reminderTimeParsed.hour,
      reminderMinute: (map['reminderMinute'] as num?)?.toInt() ?? reminderTimeParsed.minute,
      isRecurring: map['isRecurring'] as bool? ?? true,
      scheduledFor: scheduledForParsed,
      lastSentAt: lastSentAtParsed,
      createdAt: createdAtParsed,
    );
  }
}
