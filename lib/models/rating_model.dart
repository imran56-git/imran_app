import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String ratingId;
  final String teacherId;
  final String studentId;
  final String connectionId;
  final String subjectId;
  final double stars;
  final double teachingQuality;
  final double behaviour;
  final double communication;
  final double knowledge;
  final double punctuality;
  final String review;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String season;
  final String seasonId;
  final bool isVerified;
  final String status;
  final String? rejectionReason;
  final int updateCount;
  final String? teacherReply;
  final DateTime? teacherReplyTime;

  RatingModel({
    required this.ratingId,
    required this.teacherId,
    required this.studentId,
    this.connectionId = '',
    this.subjectId = 'general',
    required this.stars,
    double? teachingQuality,
    double? behaviour,
    double? communication,
    double? knowledge,
    double? punctuality,
    required this.review,
    required this.createdAt,
    this.updatedAt,
    required this.season,
    String? seasonId,
    this.isVerified = false,
    String? status,
    this.rejectionReason,
    this.updateCount = 0,
    this.teacherReply,
    this.teacherReplyTime,
  })  : teachingQuality = teachingQuality ?? stars,
        behaviour = behaviour ?? stars,
        communication = communication ?? stars,
        knowledge = knowledge ?? stars,
        punctuality = punctuality ?? stars,
        seasonId = seasonId ?? getCurrentSeasonId(createdAt),
        status = status ?? (isVerified ? 'verified' : 'pending');

  bool get isEligibleForCalculation => status == 'verified' || isVerified;

  Map<String, dynamic> toMap() {
    return {
      'ratingId': ratingId,
      'teacherId': teacherId,
      'studentId': studentId,
      'connectionId': connectionId,
      'subjectId': subjectId,
      'stars': stars,
      'teachingQuality': teachingQuality,
      'behaviour': behaviour,
      'communication': communication,
      'knowledge': knowledge,
      'punctuality': punctuality,
      'review': review,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'season': season,
      'seasonId': seasonId,
      'isVerified': status == 'verified' || isVerified,
      'status': status,
      'rejectionReason': rejectionReason,
      'updateCount': updateCount,
      'teacherReply': teacherReply,
      'teacherReplyTime': teacherReplyTime != null
          ? Timestamp.fromDate(teacherReplyTime!)
          : null,
    };
  }

  factory RatingModel.fromMap(Map<String, dynamic> map, String id) {
    final parsedStars = (map['stars'] as num?)?.toDouble() ?? 0.0;
    final parsedCreated =
        (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final parsedVerified = map['isVerified'] ?? false;
    final parsedStatus =
        map['status'] ?? (parsedVerified ? 'verified' : 'pending');

    return RatingModel(
      ratingId: id,
      teacherId: map['teacherId'] ?? '',
      studentId: map['studentId'] ?? '',
      connectionId: map['connectionId'] ?? '',
      subjectId: map['subjectId'] ?? 'general',
      stars: parsedStars,
      teachingQuality:
          (map['teachingQuality'] as num?)?.toDouble() ?? parsedStars,
      behaviour: (map['behaviour'] as num?)?.toDouble() ?? parsedStars,
      communication:
          (map['communication'] as num?)?.toDouble() ?? parsedStars,
      knowledge: (map['knowledge'] as num?)?.toDouble() ?? parsedStars,
      punctuality: (map['punctuality'] as num?)?.toDouble() ?? parsedStars,
      review: map['review'] ?? '',
      createdAt: parsedCreated,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      season: map['season'] ?? _getCurrentSeason(parsedCreated),
      seasonId: map['seasonId'] ?? getCurrentSeasonId(parsedCreated),
      isVerified: parsedStatus == 'verified' || parsedVerified,
      status: parsedStatus,
      rejectionReason: map['rejectionReason'],
      updateCount: (map['updateCount'] as num?)?.toInt() ?? 0,
      teacherReply: map['teacherReply'],
      teacherReplyTime: (map['teacherReplyTime'] as Timestamp?)?.toDate(),
    );
  }

  static String getCurrentSeason([DateTime? date]) {
    return _getCurrentSeason(date ?? DateTime.now());
  }

  static String getCurrentSeasonId([DateTime? date]) {
    final target = date ?? DateTime.now();
    final seasonNum = (target.month >= 1 && target.month <= 6) ? 1 : 2;
    return '${target.year}_S$seasonNum';
  }

  static String _getCurrentSeason([DateTime? date]) {
    final month = (date ?? DateTime.now()).month;
    if (month >= 1 && month <= 6) {
      return "Season 1";
    } else {
      return "Season 2";
    }
  }

  RatingModel copyWith({
    String? ratingId,
    String? teacherId,
    String? studentId,
    String? connectionId,
    String? subjectId,
    double? stars,
    double? teachingQuality,
    double? behaviour,
    double? communication,
    double? knowledge,
    double? punctuality,
    String? review,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? season,
    String? seasonId,
    bool? isVerified,
    String? status,
    String? rejectionReason,
    int? updateCount,
    String? teacherReply,
    DateTime? teacherReplyTime,
  }) {
    final nextStatus = status ?? this.status;
    final nextVerified = isVerified ?? (nextStatus == 'verified');

    return RatingModel(
      ratingId: ratingId ?? this.ratingId,
      teacherId: teacherId ?? this.teacherId,
      studentId: studentId ?? this.studentId,
      connectionId: connectionId ?? this.connectionId,
      subjectId: subjectId ?? this.subjectId,
      stars: stars ?? this.stars,
      teachingQuality: teachingQuality ?? this.teachingQuality,
      behaviour: behaviour ?? this.behaviour,
      communication: communication ?? this.communication,
      knowledge: knowledge ?? this.knowledge,
      punctuality: punctuality ?? this.punctuality,
      review: review ?? this.review,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      season: season ?? this.season,
      seasonId: seasonId ?? this.seasonId,
      isVerified: nextVerified,
      status: nextStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      updateCount: updateCount ?? this.updateCount,
      teacherReply: teacherReply ?? this.teacherReply,
      teacherReplyTime: teacherReplyTime ?? this.teacherReplyTime,
    );
  }
}
