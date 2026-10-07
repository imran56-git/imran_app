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
  })  : dayOfMonth = dayOfMonth ?? dueDate.day,
        reminderHour = reminderHour ?? reminderTime.hour,
        reminderMinute = reminderMinute ?? reminderTime.minute;

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
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    final dueDateParsed = map['dueDate'] is Timestamp
        ? (map['dueDate'] as Timestamp).toDate()
        : DateTime.now();

    final reminderTimeParsed = map['reminderTime'] is Timestamp
        ? (map['reminderTime'] as Timestamp).toDate()
        : DateTime.now();

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
      status: map['status']?.toString() ?? 'active',
      dayOfMonth: (map['dayOfMonth'] as num?)?.toInt() ?? dueDateParsed.day,
      reminderHour: (map['reminderHour'] as num?)?.toInt() ?? reminderTimeParsed.hour,
      reminderMinute: (map['reminderMinute'] as num?)?.toInt() ?? reminderTimeParsed.minute,
      isRecurring: map['isRecurring'] as bool? ?? true,
    );
  }
}
