```dart
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
  final DateTime? createdAt;
  final DateTime? lastUpdated;

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
    this.createdAt,
    this.lastUpdated,
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
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  factory DiaryModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final dateParsed = parseDate(map['date']);

    DateTime? createdAtParsed;
    if (map['createdAt'] != null) {
      createdAtParsed = parseDate(map['createdAt']);
    }

    DateTime? lastUpdatedParsed;
    if (map['lastUpdated'] != null) {
      lastUpdatedParsed = parseDate(map['lastUpdated']);
    }

    final Map<String, String> parsedStatuses = {};
    if (map['monthStatuses'] != null && map['monthStatuses'] is Map) {
      (map['monthStatuses'] as Map).forEach((key, value) {
        parsedStatuses[key.toString()] = value.toString();
      });
    }

    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value, int fallback) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    return DiaryModel(
      diaryId: map['diaryId']?.toString() ?? '',
      studentName: map['studentName']?.toString() ?? 'Student',
      studentId: map['studentId']?.toString() ?? '',
      teacherId: map['teacherId']?.toString() ?? '',
      teacherName: map['teacherName']?.toString() ?? 'Teacher',
      subject: map['subject']?.toString() ?? '',
      year: parseInt(map['year'], DateTime.now().year),
      monthlyFee: parseDouble(map['monthlyFee']),
      monthStatuses: parsedStatuses,
      paidMonthsCount: parseInt(map['paidMonthsCount'], 0),
      dueMonthsCount: parseInt(map['dueMonthsCount'], 0),
      totalPaid: parseDouble(map['totalPaid']),
      totalDue: parseDouble(map['totalDue']),
      month: map['month']?.toString() ?? '',
      date: dateParsed,
      topicCovered: map['topicCovered']?.toString() ?? '',
      homework: map['homework']?.toString() ?? '',
      privateNote: map['privateNote']?.toString() ?? '',
      createdAt: createdAtParsed,
      lastUpdated: lastUpdatedParsed,
    );
  }
}
```