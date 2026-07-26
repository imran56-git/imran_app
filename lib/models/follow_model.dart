import 'package:cloud_firestore/cloud_firestore.dart';

class FollowModel {
  final String id;
  final String teacherId;
  final String studentId;
  final String teacherName;
  final String studentName;
  final String teacherPhoto;
  final String studentPhoto;
  final String status; // pending, accepted, rejected, cancelled
  final Timestamp? requestedAt;
  final Timestamp? acceptedAt;
  final Timestamp? rejectedAt;

  FollowModel({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.teacherName,
    required this.studentName,
    required this.teacherPhoto,
    required this.studentPhoto,
    required this.status,
    this.requestedAt,
    this.acceptedAt,
    this.rejectedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'studentId': studentId,
      'teacherName': teacherName,
      'studentName': studentName,
      'teacherPhoto': teacherPhoto,
      'studentPhoto': studentPhoto,
      'status': status,
      'requestedAt': requestedAt ?? FieldValue.serverTimestamp(),
      'acceptedAt': acceptedAt,
      'rejectedAt': rejectedAt,
    };
  }

  factory FollowModel.fromMap(Map<String, dynamic> map) {
    return FollowModel(
      id: map['id'] ?? '',
      teacherId: map['teacherId'] ?? '',
      studentId: map['studentId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      studentName: map['studentName'] ?? '',
      teacherPhoto: map['teacherPhoto'] ?? '',
      studentPhoto: map['studentPhoto'] ?? '',
      status: map['status'] ?? 'pending',
      requestedAt: map['requestedAt'] as Timestamp?,
      acceptedAt: map['acceptedAt'] as Timestamp?,
      rejectedAt: map['rejectedAt'] as Timestamp?,
    );
  }
}
