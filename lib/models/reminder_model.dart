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
  });

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
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    return ReminderModel(
      reminderId: map['reminderId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentId: map['studentId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      month: map['month'] ?? '',
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      reminderTime: (map['reminderTime'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
    );
  }
}
