import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String chatId;
  final String teacherId;
  final String studentId;
  final String teacherName;
  final String studentName;
  final String teacherImage;
  final String studentImage;
  final List<String> participants;
  final String lastMessageContent; // Naming Convention সিঙ্ক করার জন্য 'lastMessage' থেকে 'lastMessageContent' করা হলো
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isGroup;
  final List<String> pinnedBy;
  final List<String> blockedBy;

  ChatModel({
    required this.chatId,
    required this.teacherId,
    required this.studentId,
    required this.teacherName,
    required this.studentName,
    required this.teacherImage,
    required this.studentImage,
    required this.participants,
    required this.lastMessageContent,
    this.lastMessageTime,
    required this.unreadCount,
    required this.isGroup,
    required this.pinnedBy,
    required this.blockedBy,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      chatId: map['chatId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      studentId: map['studentId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      studentName: map['studentName'] ?? '',
      teacherImage: map['teacherImage'] ?? '',
      studentImage: map['studentImage'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessageContent: map['lastMessageContent'] ?? map['lastMessage'] ?? '', // ব্যাকওয়ার্ড ডাটাবেস সেফটির জন্য ওল্ড কী সাপোর্ট রাখা হলো
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] is Timestamp 
              ? (map['lastMessageTime'] as Timestamp).toDate() 
              : DateTime.tryParse(map['lastMessageTime'].toString()))
          : null,
      unreadCount: map['unreadCount'] ?? 0,
      isGroup: map['isGroup'] ?? false,
      pinnedBy: List<String>.from(map['pinnedBy'] ?? []),
      blockedBy: List<String>.from(map['blockedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'teacherId': teacherId,
      'studentId': studentId,
      'teacherName': teacherName,
      'studentName': studentName,
      'teacherImage': teacherImage,
      'studentImage': studentImage,
      'participants': participants,
      'lastMessageContent': lastMessageContent,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : FieldValue.serverTimestamp(), // রিয়েল-টাইম ফায়ারস্টোর সার্ভার টাইমস্ট্যাম্প
      'unreadCount': unreadCount,
      'isGroup': isGroup,
      'pinnedBy': pinnedBy,
      'blockedBy': blockedBy,
    };
  }
}
