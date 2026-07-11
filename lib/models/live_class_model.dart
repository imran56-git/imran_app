import 'package:cloud_firestore/cloud_firestore.dart';

class LiveClassModel {
  final String roomId;
  final String title;
  final String teacherId;
  final String teacherName;
  final bool isLive;
  final DateTime createdAt;
  final bool isMicMuted;
  final bool isCameraOff;
  final List<String> participants;
  final List<String> handRaisedUsers;
  final List<String> allowedMicUsers;

  LiveClassModel({
    required this.roomId,
    required this.title,
    required this.teacherId,
    required this.teacherName,
    required this.isLive,
    required this.createdAt,
    required this.isMicMuted,
    required this.isCameraOff,
    required this.participants,
    required this.handRaisedUsers,
    required this.allowedMicUsers,
  });

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'title': title,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'isLive': isLive,
      'createdAt': Timestamp.fromDate(createdAt),
      'isMicMuted': isMicMuted,
      'isCameraOff': isCameraOff,
      'participants': participants,
      'handRaisedUsers': handRaisedUsers,
      'allowedMicUsers': allowedMicUsers,
    };
  }

  factory LiveClassModel.fromMap(Map<String, dynamic> map) {
    return LiveClassModel(
      roomId: map['roomId'] ?? '',
      title: map['title'] ?? '',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      isLive: map['isLive'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isMicMuted: map['isMicMuted'] ?? false,
      isCameraOff: map['isCameraOff'] ?? false,
      participants: List<String>.from(map['participants'] ?? []),
      handRaisedUsers: List<String>.from(map['handRaisedUsers'] ?? []),
      allowedMicUsers: List<String>.from(map['allowedMicUsers'] ?? []),
    );
  }
}
