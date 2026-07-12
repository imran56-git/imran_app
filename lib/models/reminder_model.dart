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
      reminderId: map['reminderId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? 'Student',
      studentId: map['studentId']?.toString() ?? '',
      teacherId: map['teacherId']?.toString() ?? '',
      teacherName: map['teacherName']?.toString() ?? 'Teacher',
      // ইন্টিজার ও ডাবল প্রপারলি হ্যান্ডেল করার কাস্টিং ফিক্স
      amount: map['amount'] is num ? (map['amount'] as num).toDouble() : (double.tryParse(map['amount']?.toString() ?? '0.0') ?? 0.0),
      month: map['month']?.toString() ?? '',
      dueDate: map['dueDate'] is Timestamp 
          ? (map['dueDate'] as Timestamp).toDate() 
          : DateTime.now(),
      reminderTime: map['reminderTime'] is Timestamp 
          ? (map['reminderTime'] as Timestamp).toDate() 
          : DateTime.now(),
      status: map['status']?.toString() ?? 'pending',
    );
  }
}
