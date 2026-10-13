import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String createdBy;
  final String imageUrl;
  final List<String> members;
  final Timestamp createdAt;
  final String description;
  final String batchName;
  final String className;
  final String subjectName;
  final String courseName;
  final String academicYear;
  final String groupRules;
  final String welcomeMessage;
  final String teacherName;
  final String teacherProfilePic;
  final bool isTeacherVerified;
  final bool hasGoldenBadge;
  final String teacherCredentials;
  final double teacherRating;
  final bool onlyAdminCanPost;
  final List<String> mutedStudents;
  final bool isDismissed;
  final Timestamp? dismissedAt;
  final List<String> unacknowledgedDismissMembers;
  final List<String> removedStudents;
  final List<String> pendingRemovalNotices;
  final String lastMessage;
  final Timestamp? lastMessageTime;
  final String lastSenderId;
  final List<String> pinnedMessageIds;
  final List<String> mutedByUsers;
  final List<String> archivedByUsers;
  final Map<String, int> unreadCounts;
  final int disappearingDurationHours;

  GroupModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.imageUrl,
    required this.members,
    required this.createdAt,
    this.description = '',
    this.batchName = '',
    this.className = '',
    this.subjectName = '',
    this.courseName = '',
    this.academicYear = '',
    this.groupRules = '',
    this.welcomeMessage = '',
    this.teacherName = '',
    this.teacherProfilePic = '',
    this.isTeacherVerified = false,
    this.hasGoldenBadge = false,
    this.teacherCredentials = '',
    this.teacherRating = 0.0,
    this.onlyAdminCanPost = false,
    this.mutedStudents = const [],
    this.isDismissed = false,
    this.dismissedAt,
    this.unacknowledgedDismissMembers = const [],
    this.removedStudents = const [],
    this.pendingRemovalNotices = const [],
    this.lastMessage = '',
    this.lastMessageTime,
    this.lastSenderId = '',
    this.pinnedMessageIds = const [],
    this.mutedByUsers = const [],
    this.archivedByUsers = const [],
    this.unreadCounts = const {},
    this.disappearingDurationHours = 0,
  });

  bool isSingleAdmin(String userId) {
    return userId.isNotEmpty && userId == createdBy;
  }

  bool isStudentMuted(String userId) {
    return mutedStudents.contains(userId);
  }

  bool isStudentRemoved(String userId) {
    return removedStudents.contains(userId);
  }

  bool canUserSendMessage(String userId) {
    if (isDismissed) return false;
    if (isSingleAdmin(userId)) return true;
    if (!members.contains(userId)) return false;
    if (isStudentRemoved(userId)) return false;
    if (isStudentMuted(userId)) return false;
    if (onlyAdminCanPost) return false;
    return true;
  }

  int get studentCount {
    return members.where((uid) => uid != createdBy).length;
  }

  int getUnreadCountForUser(String userId) {
    return unreadCounts[userId] ?? 0;
  }

  factory GroupModel.fromMap(Map<String, dynamic> data, String docId) {
    List<String> parseStringList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return const [];
    }

    Map<String, int> parseUnreadMap(dynamic raw) {
      if (raw is Map) {
        return raw.map((key, value) => MapEntry(
              key.toString(),
              value is int ? value : int.tryParse(value.toString()) ?? 0,
            ));
      }
      return const {};
    }

    Timestamp? parseTimestamp(dynamic raw) {
      if (raw is Timestamp) return raw;
      if (raw is DateTime) return Timestamp.fromDate(raw);
      return null;
    }

    return GroupModel(
      id: docId.isNotEmpty
          ? docId
          : (data['id'] ?? data['groupId'] ?? '').toString(),
      name: (data['name'] ?? data['groupName'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? data['teacherId'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ??
              data['groupImageUrl'] ??
              data['groupImage'] ??
              '')
          .toString(),
      members: parseStringList(data['members']),
      createdAt: parseTimestamp(data['createdAt']) ?? Timestamp.now(),
      description: (data['description'] ?? '').toString(),
      batchName: (data['batchName'] ?? '').toString(),
      className: (data['className'] ?? '').toString(),
      subjectName: (data['subjectName'] ?? '').toString(),
      courseName: (data['courseName'] ?? '').toString(),
      academicYear: (data['academicYear'] ?? '').toString(),
      groupRules: (data['groupRules'] ?? '').toString(),
      welcomeMessage: (data['welcomeMessage'] ?? '').toString(),
      teacherName: (data['teacherName'] ?? '').toString(),
      teacherProfilePic: (data['teacherProfilePic'] ?? '').toString(),
      isTeacherVerified: data['isTeacherVerified'] as bool? ?? false,
      hasGoldenBadge: data['hasGoldenBadge'] as bool? ?? false,
      teacherCredentials: (data['teacherCredentials'] ?? '').toString(),
      teacherRating: (data['teacherRating'] is num)
          ? (data['teacherRating'] as num).toDouble()
          : 0.0,
      onlyAdminCanPost: data['onlyAdminCanPost'] as bool? ?? false,
      mutedStudents: parseStringList(data['mutedStudents']),
      isDismissed: data['isDismissed'] as bool? ?? false,
      dismissedAt: parseTimestamp(data['dismissedAt']),
      unacknowledgedDismissMembers:
          parseStringList(data['unacknowledgedDismissMembers']),
      removedStudents: parseStringList(data['removedStudents']),
      pendingRemovalNotices: parseStringList(data['pendingRemovalNotices']),
      lastMessage: (data['lastMessage'] ?? '').toString(),
      lastMessageTime: parseTimestamp(data['lastMessageTime']) ??
          parseTimestamp(data['lastMessageTimestamp']),
      lastSenderId: (data['lastSenderId'] ?? '').toString(),
      pinnedMessageIds: parseStringList(data['pinnedMessageIds']),
      mutedByUsers: parseStringList(data['mutedByUsers']),
      archivedByUsers: parseStringList(data['archivedByUsers']),
      unreadCounts: parseUnreadMap(data['unreadCounts']),
      disappearingDurationHours: (data['disappearingDurationHours'] is int)
          ? data['disappearingDurationHours'] as int
          : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': id,
      'name': name,
      'groupName': name,
      'createdBy': createdBy,
      'teacherId': createdBy,
      'admins': [createdBy],
      'imageUrl': imageUrl,
      'groupImageUrl': imageUrl,
      'members': members,
      'createdAt': createdAt,
      'description': description,
      'batchName': batchName,
      'className': className,
      'subjectName': subjectName,
      'courseName': courseName,
      'academicYear': academicYear,
      'groupRules': groupRules,
      'welcomeMessage': welcomeMessage,
      'teacherName': teacherName,
      'teacherProfilePic': teacherProfilePic,
      'isTeacherVerified': isTeacherVerified,
      'hasGoldenBadge': hasGoldenBadge,
      'teacherCredentials': teacherCredentials,
      'teacherRating': teacherRating,
      'onlyAdminCanPost': onlyAdminCanPost,
      'mutedStudents': mutedStudents,
      'isDismissed': isDismissed,
      'dismissedAt': dismissedAt,
      'unacknowledgedDismissMembers': unacknowledgedDismissMembers,
      'removedStudents': removedStudents,
      'pendingRemovalNotices': pendingRemovalNotices,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime ?? createdAt,
      'lastMessageTimestamp': lastMessageTime ?? createdAt,
      'lastSenderId': lastSenderId,
      'pinnedMessageIds': pinnedMessageIds,
      'mutedByUsers': mutedByUsers,
      'archivedByUsers': archivedByUsers,
      'unreadCounts': unreadCounts,
      'disappearingDurationHours': disappearingDurationHours,
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? createdBy,
    String? imageUrl,
    List<String>? members,
    Timestamp? createdAt,
    String? description,
    String? batchName,
    String? className,
    String? subjectName,
    String? courseName,
    String? academicYear,
    String? groupRules,
    String? welcomeMessage,
    String? teacherName,
    String? teacherProfilePic,
    bool? isTeacherVerified,
    bool? hasGoldenBadge,
    String? teacherCredentials,
    double? teacherRating,
    bool? onlyAdminCanPost,
    List<String>? mutedStudents,
    bool? isDismissed,
    Timestamp? dismissedAt,
    List<String>? unacknowledgedDismissMembers,
    List<String>? removedStudents,
    List<String>? pendingRemovalNotices,
    String? lastMessage,
    Timestamp? lastMessageTime,
    String? lastSenderId,
    List<String>? pinnedMessageIds,
    List<String>? mutedByUsers,
    List<String>? archivedByUsers,
    Map<String, int>? unreadCounts,
    int? disappearingDurationHours,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      imageUrl: imageUrl ?? this.imageUrl,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      batchName: batchName ?? this.batchName,
      className: className ?? this.className,
      subjectName: subjectName ?? this.subjectName,
      courseName: courseName ?? this.courseName,
      academicYear: academicYear ?? this.academicYear,
      groupRules: groupRules ?? this.groupRules,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
      teacherName: teacherName ?? this.teacherName,
      teacherProfilePic: teacherProfilePic ?? this.teacherProfilePic,
      isTeacherVerified: isTeacherVerified ?? this.isTeacherVerified,
      hasGoldenBadge: hasGoldenBadge ?? this.hasGoldenBadge,
      teacherCredentials: teacherCredentials ?? this.teacherCredentials,
      teacherRating: teacherRating ?? this.teacherRating,
      onlyAdminCanPost: onlyAdminCanPost ?? this.onlyAdminCanPost,
      mutedStudents: mutedStudents ?? this.mutedStudents,
      isDismissed: isDismissed ?? this.isDismissed,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      unacknowledgedDismissMembers:
          unacknowledgedDismissMembers ?? this.unacknowledgedDismissMembers,
      removedStudents: removedStudents ?? this.removedStudents,
      pendingRemovalNotices:
          pendingRemovalNotices ?? this.pendingRemovalNotices,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      pinnedMessageIds: pinnedMessageIds ?? this.pinnedMessageIds,
      mutedByUsers: mutedByUsers ?? this.mutedByUsers,
      archivedByUsers: archivedByUsers ?? this.archivedByUsers,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      disappearingDurationHours:
          disappearingDurationHours ?? this.disappearingDurationHours,
    );
  }
}
