import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/algorithm_config.dart';

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
  final String? replyText;
  final bool isEdited;
  final DateTime? editTimestamp;
  final Map<String, dynamic>? mediaMetaData;
  final String senderRole;
  final String senderName;
  final String senderProfilePic;
  final bool isSenderVerified;
  final bool hasSenderGoldenBadge;
  final String messageCategory;
  final bool isPinned;
  final bool isForwarded;
  final List<String> deliveredTo;
  final List<String> readBy;
  final Map<String, dynamic>? pollData;
  final Map<String, dynamic>? quizData;
  final Map<String, dynamic>? linkPreviewData;
  final Map<String, dynamic>? ratingPromptData;
  final bool isScheduled;
  final DateTime? scheduledAt;
  final DateTime? expiresAt;
  final int replyThreadCount;
  final String? parentThreadMessageId;
  final String? clientMessageId;
  final List<String> reportedBy;

  const MessageModel({
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
    this.replyText,
    this.isEdited = false,
    this.editTimestamp,
    this.mediaMetaData,
    this.senderRole = 'student',
    this.senderName = '',
    this.senderProfilePic = '',
    this.isSenderVerified = false,
    this.hasSenderGoldenBadge = false,
    this.messageCategory = 'general',
    this.isPinned = false,
    this.isForwarded = false,
    this.deliveredTo = const [],
    this.readBy = const [],
    this.pollData,
    this.quizData,
    this.linkPreviewData,
    this.ratingPromptData,
    this.isScheduled = false,
    this.scheduledAt,
    this.expiresAt,
    this.replyThreadCount = 0,
    this.parentThreadMessageId,
    this.clientMessageId,
    this.reportedBy = const [],
  });

  bool get isSeasonRatingPrompt =>
      type == AlgorithmConfig.seasonRatingMessageType ||
      messageCategory == AlgorithmConfig.seasonRatingMessageType;

  String get promptTeacherId =>
      ratingPromptData?['teacherId']?.toString() ?? senderId;

  String get promptSeasonId =>
      ratingPromptData?['seasonId']?.toString() ?? '';

  String get promptConnectionId =>
      ratingPromptData?['connectionId']?.toString() ?? '';

  bool get canTriggerDirectRating =>
      isSeasonRatingPrompt && promptTeacherId.isNotEmpty;

  factory MessageModel.createSeasonRatingPrompt({
    required String messageId,
    required String teacherId,
    required String studentId,
    required String teacherName,
    required String studentName,
    required String teacherProfilePic,
    required String seasonId,
    required String seasonName,
    required String connectionId,
    String subjectId = 'general',
    bool isTeacherVerified = false,
    bool hasTeacherGoldenBadge = false,
  }) {
    final promptText = AlgorithmConfig.buildSeasonalRatingPromptMessage(
      studentName: studentName,
      teacherName: teacherName,
      seasonName: seasonName,
    );

    return MessageModel(
      messageId: messageId,
      senderId: teacherId,
      receiverId: studentId,
      content: promptText,
      timestamp: DateTime.now(),
      type: AlgorithmConfig.seasonRatingMessageType,
      status: 'sent',
      isDeletedForEveryone: false,
      deletedForUsers: const [],
      starredBy: const [],
      reactions: const {},
      senderRole: 'teacher',
      senderName: teacherName,
      senderProfilePic: teacherProfilePic,
      isSenderVerified: isTeacherVerified,
      hasSenderGoldenBadge: hasTeacherGoldenBadge,
      messageCategory: AlgorithmConfig.seasonRatingMessageType,
      ratingPromptData: {
        'teacherId': teacherId,
        'studentId': studentId,
        'teacherName': teacherName,
        'seasonId': seasonId,
        'seasonName': seasonName,
        'connectionId': connectionId,
        'subjectId': subjectId,
        'actionLabel': 'Rate Teacher Now',
        'isDirectRatingEnabled': true,
      },
    );
  }

  String getVisibleSenderName({
    required String currentUserId,
    required bool isViewerTeacherOfGroup,
  }) {
    if (senderId == currentUserId) return 'You';
    if (senderRole == 'teacher') {
      return senderName.isNotEmpty ? senderName : 'Teacher';
    }
    if (isViewerTeacherOfGroup) {
      return senderName.isNotEmpty ? senderName : 'Student';
    }
    return 'Student';
  }

  bool canOpenSenderProfile({
    required String currentUserId,
    required bool isViewerTeacherOfGroup,
  }) {
    if (senderId == currentUserId) return false;
    if (senderRole == 'teacher') return true;
    if (isViewerTeacherOfGroup) return true;
    return false;
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDateTime(dynamic raw) {
      if (raw == null) return null;
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return const [];
    }

    Map<String, dynamic>? parseDynamicMap(dynamic raw) {
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
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
      deletedForUsers: parseStringList(map['deletedForUsers']),
      starredBy: parseStringList(map['starredBy']),
      reactions: (map['reactions'] as Map<dynamic, dynamic>?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
      replyToMessageId: map['replyToMessageId']?.toString(),
      replyText: map['replyText']?.toString() ?? map['replyToText']?.toString(),
      isEdited: map['isEdited'] as bool? ?? false,
      editTimestamp: parseDateTime(map['editTimestamp']),
      mediaMetaData: parseDynamicMap(map['mediaMetaData']),
      senderRole: map['senderRole']?.toString() ?? 'student',
      senderName: map['senderName']?.toString() ?? '',
      senderProfilePic: map['senderProfilePic']?.toString() ?? '',
      isSenderVerified: map['isSenderVerified'] as bool? ?? false,
      hasSenderGoldenBadge: map['hasSenderGoldenBadge'] as bool? ?? false,
      messageCategory: map['messageCategory']?.toString() ?? 'general',
      isPinned: map['isPinned'] as bool? ?? false,
      isForwarded: map['isForwarded'] as bool? ?? false,
      deliveredTo: parseStringList(map['deliveredTo']),
      readBy: parseStringList(map['readBy']),
      pollData: parseDynamicMap(map['pollData']),
      quizData: parseDynamicMap(map['quizData']),
      linkPreviewData: parseDynamicMap(map['linkPreviewData']),
      ratingPromptData: parseDynamicMap(map['ratingPromptData']),
      isScheduled: map['isScheduled'] as bool? ?? false,
      scheduledAt: parseDateTime(map['scheduledAt']),
      expiresAt: parseDateTime(map['expiresAt']),
      replyThreadCount: (map['replyThreadCount'] is int)
          ? map['replyThreadCount'] as int
          : 0,
      parentThreadMessageId: map['parentThreadMessageId']?.toString(),
      clientMessageId: map['clientMessageId']?.toString(),
      reportedBy: parseStringList(map['reportedBy']),
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
      'replyText': replyText,
      'replyToText': replyText,
      'isEdited': isEdited,
      'editTimestamp':
          editTimestamp != null ? Timestamp.fromDate(editTimestamp!) : null,
      'mediaMetaData': mediaMetaData,
      'senderRole': senderRole,
      'senderName': senderName,
      'senderProfilePic': senderProfilePic,
      'isSenderVerified': isSenderVerified,
      'hasSenderGoldenBadge': hasSenderGoldenBadge,
      'messageCategory': messageCategory,
      'isPinned': isPinned,
      'isForwarded': isForwarded,
      'deliveredTo': deliveredTo,
      'readBy': readBy,
      'pollData': pollData,
      'quizData': quizData,
      'linkPreviewData': linkPreviewData,
      'ratingPromptData': ratingPromptData,
      'isScheduled': isScheduled,
      'scheduledAt':
          scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'replyThreadCount': replyThreadCount,
      'parentThreadMessageId': parentThreadMessageId,
      'clientMessageId': clientMessageId,
      'reportedBy': reportedBy,
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
    String? replyText,
    bool? isEdited,
    DateTime? editTimestamp,
    Map<String, dynamic>? mediaMetaData,
    String? senderRole,
    String? senderName,
    String? senderProfilePic,
    bool? isSenderVerified,
    bool? hasSenderGoldenBadge,
    String? messageCategory,
    bool? isPinned,
    bool? isForwarded,
    List<String>? deliveredTo,
    List<String>? readBy,
    Map<String, dynamic>? pollData,
    Map<String, dynamic>? quizData,
    Map<String, dynamic>? linkPreviewData,
    Map<String, dynamic>? ratingPromptData,
    bool? isScheduled,
    DateTime? scheduledAt,
    DateTime? expiresAt,
    int? replyThreadCount,
    String? parentThreadMessageId,
    String? clientMessageId,
    List<String>? reportedBy,
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
      replyText: replyText ?? this.replyText,
      isEdited: isEdited ?? this.isEdited,
      editTimestamp: editTimestamp ?? this.editTimestamp,
      mediaMetaData: mediaMetaData ?? this.mediaMetaData,
      senderRole: senderRole ?? this.senderRole,
      senderName: senderName ?? this.senderName,
      senderProfilePic: senderProfilePic ?? this.senderProfilePic,
      isSenderVerified: isSenderVerified ?? this.isSenderVerified,
      hasSenderGoldenBadge: hasSenderGoldenBadge ?? this.hasSenderGoldenBadge,
      messageCategory: messageCategory ?? this.messageCategory,
      isPinned: isPinned ?? this.isPinned,
      isForwarded: isForwarded ?? this.isForwarded,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      readBy: readBy ?? this.readBy,
      pollData: pollData ?? this.pollData,
      quizData: quizData ?? this.quizData,
      linkPreviewData: linkPreviewData ?? this.linkPreviewData,
      ratingPromptData: ratingPromptData ?? this.ratingPromptData,
      isScheduled: isScheduled ?? this.isScheduled,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      expiresAt: expiresAt ?? this.expiresAt,
      replyThreadCount: replyThreadCount ?? this.replyThreadCount,
      parentThreadMessageId:
          parentThreadMessageId ?? this.parentThreadMessageId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      reportedBy: reportedBy ?? this.reportedBy,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MessageModel &&
        other.messageId == messageId &&
        other.senderId == senderId &&
        other.receiverId == receiverId &&
        other.content == content &&
        other.type == type &&
        other.status == status &&
        other.isDeletedForEveryone == isDeletedForEveryone &&
        other.isEdited == isEdited &&
        other.isPinned == isPinned &&
        other.messageCategory == messageCategory;
  }

  @override
  int get hashCode {
    return messageId.hashCode ^
        senderId.hashCode ^
        receiverId.hashCode ^
        content.hashCode ^
        type.hashCode ^
        status.hashCode ^
        isDeletedForEveryone.hashCode ^
        isEdited.hashCode ^
        isPinned.hashCode ^
        messageCategory.hashCode;
  }
}
