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
    DateTime? parseDateTime(dynamic raw) {
      if (raw == null) return null;
      if (raw is Timestamp) return raw.toDate();
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return MessageModel(
      messageId: map['messageId']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      receiverId: map['receiverId']?.toString() ?? '',
      content: map['content']?.toString() ?? map['message']?.toString() ?? '', 

      timestamp: parseDateTime(map['timestamp']),

      type: map['type']?.toString() ?? 'text',
      status: map['status']?.toString() ?? 'sent',
      isDeletedForEveryone: map['isDeletedForEveryone'] as bool? ?? false,

      deletedForUsers: (map['deletedForUsers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? 
          [],

      starredBy: (map['starredBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? 
          [],

      reactions: (map['reactions'] as Map<dynamic, dynamic>?)
              ?.map((key, value) => MapEntry(key.toString(), value.toString())) ?? 
          {},

      replyToMessageId: map['replyToMessageId']?.toString(),
      isEdited: map['isEdited'] as bool? ?? false,

      editTimestamp: parseDateTime(map['editTimestamp']),

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

  MessageModel copyWith({
    String? messageId,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? timestamp,
    String? type,
    String? status,
    bool? isDeletedForEveryone,
    List<String>? deletedForUsers,
    List<String>? starredBy,
    Map<String, String>? reactions,
    String? replyToMessageId,
    bool? isEdited,
    DateTime? editTimestamp,
    Map<String, dynamic>? mediaMetaData,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      status: status ?? this.status,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      deletedForUsers: deletedForUsers ?? this.deletedForUsers,
      starredBy: starredBy ?? this.starredBy,
      reactions: reactions ?? this.reactions,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      isEdited: isEdited ?? this.isEdited,
      editTimestamp: editTimestamp ?? this.editTimestamp,
      mediaMetaData: mediaMetaData ?? this.mediaMetaData,
    );
  }
}
