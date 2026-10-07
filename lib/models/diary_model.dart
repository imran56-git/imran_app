import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryModel {
  final String diaryId;
  final String studentName;
  final String studentId;
  final String teacherId;
  final String teacherName;
  final String subject;
  final int year;
  final double monthlyFee;
  final Map<String, String> monthStatuses;
  final int paidMonthsCount;
  final int dueMonthsCount;
  final double totalPaid;
  final double totalDue;
  final String month;
  final DateTime date;
  final String topicCovered;
  final String homework;
  final String privateNote;

  DiaryModel({
    required this.diaryId,
    required this.studentName,
    required this.studentId,
    required this.teacherId,
    this.teacherName = 'Teacher',
    required this.subject,
    int? year,
    double? monthlyFee,
    Map<String, String>? monthStatuses,
    int? paidMonthsCount,
    int? dueMonthsCount,
    double? totalPaid,
    double? totalDue,
    this.month = '',
    DateTime? date,
    this.topicCovered = '',
    this.homework = '',
    this.privateNote = '',
  })  : year = year ?? DateTime.now().year,
        monthlyFee = monthlyFee ?? 0.0,
        monthStatuses = monthStatuses ?? const {},
        paidMonthsCount = paidMonthsCount ?? 0,
        dueMonthsCount = dueMonthsCount ?? 0,
        totalPaid = totalPaid ?? 0.0,
        totalDue = totalDue ?? 0.0,
        date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'diaryId': diaryId,
      'studentName': studentName,
      'studentId': studentId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'subject': subject,
      'year': year,
      'monthlyFee': monthlyFee,
      'monthStatuses': monthStatuses,
      'paidMonthsCount': paidMonthsCount,
      'dueMonthsCount': dueMonthsCount,
      'totalPaid': totalPaid,
      'totalDue': totalDue,
      'month': month,
      'date': Timestamp.fromDate(date),
      'topicCovered': topicCovered,
      'homework': homework,
      'privateNote': privateNote,
    };
  }

  factory DiaryModel.fromMap(Map<String, dynamic> map) {
    final dateParsed = map['date'] is Timestamp
        ? (map['date'] as Timestamp).toDate()
        : DateTime.now();

    final Map<String, String> parsedStatuses = {};
    if (map['monthStatuses'] != null && map['monthStatuses'] is Map) {
      (map['monthStatuses'] as Map).forEach((key, value) {
        parsedStatuses[key.toString()] = value.toString();
      });
    }

    return DiaryModel(
      diaryId: map['diaryId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? 'Student',
      studentId: map['studentId']?.toString() ?? '',
      teacherId: map['teacherId']?.toString() ?? '',
      teacherName: map['teacherName']?.toString() ?? 'Teacher',
      subject: map['subject']?.toString() ?? '',
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      monthlyFee: (map['monthlyFee'] as num?)?.toDouble() ?? 0.0,
      monthStatuses: parsedStatuses,
      paidMonthsCount: (map['paidMonthsCount'] as num?)?.toInt() ?? 0,
      dueMonthsCount: (map['dueMonthsCount'] as num?)?.toInt() ?? 0,
      totalPaid: (map['totalPaid'] as num?)?.toDouble() ?? 0.0,
      totalDue: (map['totalDue'] as num?)?.toDouble() ?? 0.0,
      month: map['month']?.toString() ?? '',
      date: dateParsed,
      topicCovered: map['topicCovered']?.toString() ?? '',
      homework: map['homework']?.toString() ?? '',
      privateNote: map['privateNote']?.toString() ?? '',
    );
  }
}
