import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../constants/algorithm_config.dart';
import 'season_model.dart';

class CategoryRating extends Equatable {
  final double teaching;
  final double behaviour;
  final double communication;
  final double knowledge;
  final double punctuality;

  const CategoryRating({
    required this.teaching,
    required this.behaviour,
    required this.communication,
    required this.knowledge,
    required this.punctuality,
  });

  double get overallAverage {
    return double.parse(
      ((teaching + behaviour + communication + knowledge + punctuality) / 5.0)
          .toStringAsFixed(1),
    );
  }

  factory CategoryRating.fromMap(Map<String, dynamic> map) {
    return CategoryRating(
      teaching: (map['teaching'] as num?)?.toDouble() ??
          (map['teaching_quality'] as num?)?.toDouble() ??
          0.0,
      behaviour: (map['behaviour'] as num?)?.toDouble() ?? 0.0,
      communication: (map['communication'] as num?)?.toDouble() ?? 0.0,
      knowledge: (map['knowledge'] as num?)?.toDouble() ?? 0.0,
      punctuality: (map['punctuality'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teaching': teaching,
      'behaviour': behaviour,
      'communication': communication,
      'knowledge': knowledge,
      'punctuality': punctuality,
    };
  }

  CategoryRating copyWith({
    double? teaching,
    double? behaviour,
    double? communication,
    double? knowledge,
    double? punctuality,
  }) {
    return CategoryRating(
      teaching: teaching ?? this.teaching,
      behaviour: behaviour ?? this.behaviour,
      communication: communication ?? this.communication,
      knowledge: knowledge ?? this.knowledge,
      punctuality: punctuality ?? this.punctuality,
    );
  }

  @override
  List<Object?> get props => [
        teaching,
        behaviour,
        communication,
        knowledge,
        punctuality,
      ];
}

class ReviewModel extends Equatable {
  final String id;
  final String teacherId;
  final String studentId;
  final String studentName;
  final String studentPhotoUrl;
  final String connectionId;
  final String subjectId;
  final String seasonId;
  final CategoryRating categories;
  final double overallRating;
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? teacherReply;
  final DateTime? teacherReplyAt;
  final List<String> helpfulStudentIds;
  final List<String> reportedByStudentIds;
  final bool isEdited;
  final String status;
  final bool isVerified;
  final String? rejectionReason;
  final String? flagReason;
  final int updateCount;
  final String ruleVersion;

  const ReviewModel({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.studentName,
    required this.studentPhotoUrl,
    this.connectionId = '',
    this.subjectId = 'general',
    this.seasonId = '',
    required this.categories,
    required this.overallRating,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
    this.teacherReply,
    this.teacherReplyAt,
    this.helpfulStudentIds = const [],
    this.reportedByStudentIds = const [],
    this.isEdited = false,
    this.status = 'verified',
    this.isVerified = true,
    this.rejectionReason,
    this.flagReason,
    this.updateCount = 0,
    this.ruleVersion = AlgorithmConfig.currentRuleVersion,
  });

  bool get canBeEdited {
    if (!AlgorithmConfig.allowRatingUpdatesWithinSeason) {
      return false;
    }
    final currentSeasonId = SeasonModel.current().id;
    if (seasonId.isNotEmpty && seasonId != currentSeasonId) {
      return false;
    }
    final now = DateTime.now();
    final difference = now.difference(createdAt).inDays;
    return difference <= 180;
  }

  bool get isEligibleForCalculation =>
      status == 'verified' && isVerified;

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return ReviewModel.fromMap(map, doc.id);
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, String docId) {
    final categoriesMap = map['categories'] as Map<String, dynamic>? ?? {};
    final categoryRating = CategoryRating.fromMap(categoriesMap);
    final parsedCreatedAt =
        (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final parsedStatus = (map['status'] as String?) ??
        ((map['isVerified'] == false) ? 'pending' : 'verified');
    final parsedVerified =
        (map['isVerified'] as bool?) ?? (parsedStatus == 'verified');
    final defaultSeasonId = SeasonModel.forDate(parsedCreatedAt).id;

    return ReviewModel(
      id: docId,
      teacherId: map['teacherId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? 'Anonymous Student',
      studentPhotoUrl: map['studentPhotoUrl'] ?? '',
      connectionId: map['connectionId'] ?? '',
      subjectId: map['subjectId'] ?? 'general',
      seasonId: map['seasonId'] ?? defaultSeasonId,
      categories: categoryRating,
      overallRating: (map['overallRating'] as num?)?.toDouble() ??
          categoryRating.overallAverage,
      comment: map['comment'] ?? '',
      createdAt: parsedCreatedAt,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      teacherReply: map['teacherReply'],
      teacherReplyAt: (map['teacherReplyAt'] as Timestamp?)?.toDate(),
      helpfulStudentIds:
          List<String>.from(map['helpfulStudentIds'] as List? ?? []),
      reportedByStudentIds:
          List<String>.from(map['reportedByStudentIds'] as List? ?? []),
      isEdited: map['isEdited'] ?? false,
      status: parsedStatus,
      isVerified: parsedVerified,
      rejectionReason: map['rejectionReason'],
      flagReason: map['flagReason'],
      updateCount: (map['updateCount'] as num?)?.toInt() ?? 0,
      ruleVersion: map['ruleVersion'] ?? AlgorithmConfig.currentRuleVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'studentId': studentId,
      'studentName': studentName,
      'studentPhotoUrl': studentPhotoUrl,
      'connectionId': connectionId,
      'subjectId': subjectId,
      'seasonId': seasonId.isNotEmpty
          ? seasonId
          : SeasonModel.forDate(createdAt).id,
      'categories': categories.toMap(),
      'overallRating': overallRating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'teacherReply': teacherReply,
      'teacherReplyAt':
          teacherReplyAt != null ? Timestamp.fromDate(teacherReplyAt!) : null,
      'helpfulStudentIds': helpfulStudentIds,
      'reportedByStudentIds': reportedByStudentIds,
      'isEdited': isEdited,
      'status': status,
      'isVerified': isVerified,
      'rejectionReason': rejectionReason,
      'flagReason': flagReason,
      'updateCount': updateCount,
      'ruleVersion': ruleVersion,
    };
  }

  ReviewModel copyWith({
    String? id,
    String? teacherId,
    String? studentId,
    String? studentName,
    String? studentPhotoUrl,
    String? connectionId,
    String? subjectId,
    String? seasonId,
    CategoryRating? categories,
    double? overallRating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? teacherReply,
    DateTime? teacherReplyAt,
    List<String>? helpfulStudentIds,
    List<String>? reportedByStudentIds,
    bool? isEdited,
    String? status,
    bool? isVerified,
    String? rejectionReason,
    String? flagReason,
    int? updateCount,
    String? ruleVersion,
  }) {
    final nextStatus = status ?? this.status;
    final nextVerified = isVerified ?? (nextStatus == 'verified');

    return ReviewModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentPhotoUrl: studentPhotoUrl ?? this.studentPhotoUrl,
      connectionId: connectionId ?? this.connectionId,
      subjectId: subjectId ?? this.subjectId,
      seasonId: seasonId ?? this.seasonId,
      categories: categories ?? this.categories,
      overallRating: overallRating ?? this.overallRating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      teacherReply: teacherReply ?? this.teacherReply,
      teacherReplyAt: teacherReplyAt ?? this.teacherReplyAt,
      helpfulStudentIds: helpfulStudentIds ?? this.helpfulStudentIds,
      reportedByStudentIds: reportedByStudentIds ?? this.reportedByStudentIds,
      isEdited: isEdited ?? this.isEdited,
      status: nextStatus,
      isVerified: nextVerified,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      flagReason: flagReason ?? this.flagReason,
      updateCount: updateCount ?? this.updateCount,
      ruleVersion: ruleVersion ?? this.ruleVersion,
    );
  }

  @override
  List<Object?> get props => [
        id,
        teacherId,
        studentId,
        studentName,
        studentPhotoUrl,
        connectionId,
        subjectId,
        seasonId,
        categories,
        overallRating,
        comment,
        createdAt,
        updatedAt,
        teacherReply,
        teacherReplyAt,
        helpfulStudentIds,
        reportedByStudentIds,
        isEdited,
        status,
        isVerified,
        rejectionReason,
        flagReason,
        updateCount,
        ruleVersion,
      ];
}
