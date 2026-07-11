import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryModel {
  final String diaryId;
  final String studentName;
  final String studentId;
  final String teacherId;
  final String month;
  final DateTime date;
  final String subject;
  final String topicCovered;
  final String homework;
  final String privateNote;

  DiaryModel({
    required this.diaryId,
    required this.studentName,
    required this.studentId,
    required this.teacherId,
    required this.month,
    required this.date,
    required this.subject,
    required this.topicCovered,
    required this.homework,
    required this.privateNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'diaryId': diaryId,
      'studentName': studentName,
      'studentId': studentId,
      'teacherId': teacherId,
      'month': month,
      'date': Timestamp.fromDate(date),
      'subject': subject,
      'topicCovered': topicCovered,
      'homework': homework,
      'privateNote': privateNote,
    };
  }

  factory DiaryModel.fromMap(Map<String, dynamic> map) {
    return DiaryModel(
      diaryId: map['diaryId'] ?? '',
      studentName: map['studentName'] ?? '',
      studentId: map['studentId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      month: map['month'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      subject: map['subject'] ?? '',
      topicCovered: map['topicCovered'] ?? '',
      homework: map['homework'] ?? '',
      privateNote: map['privateNote'] ?? '',
    );
  }
}
