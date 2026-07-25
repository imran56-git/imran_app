import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String content; 
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
    required this.content,
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
      messageId: map['messageId']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      receiverId: map['receiverId']?.toString() ?? '',
      content: map['content']?.toString() ?? map['message']?.toString() ?? '', 
      
      // Timestamp Safe Parsing
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is Timestamp 
              ? (map['timestamp'] as Timestamp).toDate() 
              : DateTime.tryParse(map['timestamp'].toString()))
          : null,
          
      type: map['type']?.toString() ?? 'text',
      status: map['status']?.toString() ?? 'sent',
      isDeletedForEveryone: map['isDeletedForEveryone'] ?? false,
      
      // 100% Safe List Casting to prevent Stream crashes
      deletedForUsers: (map['deletedForUsers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? 
          [],
          
      starredBy: (map['starredBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? 
          [],
          
      // 100% Safe Map Casting
      reactions: (map['reactions'] as Map<dynamic, dynamic>?)
              ?.map((key, value) => MapEntry(key.toString(), value.toString())) ?? 
          {},
          
      replyToMessageId: map['replyToMessageId']?.toString(),
      isEdited: map['isEdited'] ?? false,
      
      // Edit Timestamp Safe Parsing
      editTimestamp: map['editTimestamp'] != null
          ? (map['editTimestamp'] is Timestamp 
              ? (map['editTimestamp'] as Timestamp).toDate() 
              : DateTime.tryParse(map['editTimestamp'].toString()))
          : null,
          
      mediaMetaData: map['mediaMetaData'] != null
          ? Map<String, dynamic>.from(map['mediaMetaData'] as Map<dynamic, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
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
