import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String attendanceId;
  final String studentId;
  final String studentName;
  final String teacherId;
  final DateTime date;
  final String status;

  AttendanceModel({
    required this.attendanceId,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'attendanceId': attendanceId,
      'studentId': studentId,
      'studentName': studentName,
      'teacherId': teacherId,
      'date': Timestamp.fromDate(date),
      'status': status,
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      attendanceId: map['attendanceId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      teacherId: map['teacherId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      status: map['status'] ?? 'Present',
    );
  }
}
