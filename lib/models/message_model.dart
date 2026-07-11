import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime? timestamp;
  final String type;
  final String status;
  final bool isDeletedForEveryone;
  final List<String> deletedForUsers;
  final List<String> starredBy;
  final Map<String, String> reactions;
  final String? replyToMessageId;
  final bool isEdited;
  final DateTime? editTimestamp;
  final Map<String, dynamic>? mediaMetaData;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.timestamp,
    required this.type,
    required this.status,
    required this.isDeletedForEveryone,
    required this.deletedForUsers,
    required this.starredBy,
    required this.reactions,
    this.replyToMessageId,
    this.isEdited = false,
    this.editTimestamp,
    this.mediaMetaData,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : null,
      type: map['type'] ?? 'text',
      status: map['status'] ?? 'sent',
      isDeletedForEveryone: map['isDeletedForEveryone'] ?? false,
      deletedForUsers: List<String>.from(map['deletedForUsers'] ?? []),
      starredBy: List<String>.from(map['starredBy'] ?? []),
      reactions: Map<String, String>.from(map['reactions'] ?? {}),
      replyToMessageId: map['replyToMessageId'],
      isEdited: map['isEdited'] ?? false,
      editTimestamp: map['editTimestamp'] != null
          ? (map['editTimestamp'] as Timestamp).toDate()
          : null,
      mediaMetaData: map['mediaMetaData'] != null
          ? Map<String, dynamic>.from(map['mediaMetaData'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp != null
          ? Timestamp.fromDate(timestamp!)
          : FieldValue.serverTimestamp(),
      'type': type,
      'status': status,
      'isDeletedForEveryone': isDeletedForEveryone,
      'deletedForUsers': deletedForUsers,
      'starredBy': starredBy,
      'reactions': reactions,
      'replyToMessageId': replyToMessageId,
      'isEdited': isEdited,
      'editTimestamp': editTimestamp != null
          ? Timestamp.fromDate(editTimestamp!)
          : null,
      'mediaMetaData': mediaMetaData,
    };
  }
}
