import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../constants/algorithm_config.dart';
import 'season_model.dart';

class SubjectRatingSummary extends Equatable {
  final String subjectId;
  final String subjectName;
  final double averageRating;
  final int verifiedReviews;
  final double competitionScore;
  final String awardedBadge;
  final String eligibilityStatus;
  final bool isSubjectVerified;

  const SubjectRatingSummary({
    required this.subjectId,
    required this.subjectName,
    this.averageRating = 0.0,
    this.verifiedReviews = 0,
    this.competitionScore = 0.0,
    this.awardedBadge = 'NONE',
    this.eligibilityStatus = AlgorithmConfig.insufficientEvidenceText,
    this.isSubjectVerified = false,
  });

  String get publicRatingDisplay => verifiedReviews > 0
      ? averageRating.toStringAsFixed(1)
      : AlgorithmConfig.noRatingDisplayText;

  factory SubjectRatingSummary.fromMap(Map<String, dynamic> map, String id) {
    return SubjectRatingSummary(
      subjectId: id.isNotEmpty ? id : (map['subjectId'] ?? 'general'),
      subjectName: map['subjectName'] ?? id,
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      verifiedReviews: (map['verifiedReviews'] as num?)?.toInt() ?? 0,
      competitionScore: (map['competitionScore'] as num?)?.toDouble() ?? 0.0,
      awardedBadge: map['awardedBadge'] ?? 'NONE',
      eligibilityStatus:
          map['eligibilityStatus'] ?? AlgorithmConfig.insufficientEvidenceText,
      isSubjectVerified: map['isSubjectVerified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subjectId': subjectId,
      'subjectName': subjectName,
      'averageRating': averageRating,
      'verifiedReviews': verifiedReviews,
      'competitionScore': competitionScore,
      'awardedBadge': awardedBadge,
      'eligibilityStatus': eligibilityStatus,
      'isSubjectVerified': isSubjectVerified,
    };
  }

  SubjectRatingSummary copyWith({
    String? subjectId,
    String? subjectName,
    double? averageRating,
    int? verifiedReviews,
    double? competitionScore,
    String? awardedBadge,
    String? eligibilityStatus,
    bool? isSubjectVerified,
  }) {
    return SubjectRatingSummary(
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      averageRating: averageRating ?? this.averageRating,
      verifiedReviews: verifiedReviews ?? this.verifiedReviews,
      competitionScore: competitionScore ?? this.competitionScore,
      awardedBadge: awardedBadge ?? this.awardedBadge,
      eligibilityStatus: eligibilityStatus ?? this.eligibilityStatus,
      isSubjectVerified: isSubjectVerified ?? this.isSubjectVerified,
    );
  }

  @override
  List<Object?> get props => [
        subjectId,
        subjectName,
        averageRating,
        verifiedReviews,
        competitionScore,
        awardedBadge,
        eligibilityStatus,
        isSubjectVerified,
      ];
}

class SeasonHistoryRecord extends Equatable {
  final String seasonId;
  final String seasonName;
  final double averageRating;
  final int verifiedReviews;
  final double competitionScore;
  final String awardedBadge;
  final Map<String, String> subjectBadges;
  final String ruleVersion;
  final DateTime finalizedAt;

  const SeasonHistoryRecord({
    required this.seasonId,
    required this.seasonName,
    required this.averageRating,
    required this.verifiedReviews,
    required this.competitionScore,
    this.awardedBadge = 'NONE',
    this.subjectBadges = const {},
    this.ruleVersion = AlgorithmConfig.currentRuleVersion,
    required this.finalizedAt,
  });

  factory SeasonHistoryRecord.fromMap(Map<String, dynamic> map) {
    final rawSubjectBadges =
        map['subjectBadges'] as Map<String, dynamic>? ?? {};
    final parsedSubjectBadges = <String, String>{};
    rawSubjectBadges.forEach((key, value) {
      parsedSubjectBadges[key] = value.toString();
    });

    return SeasonHistoryRecord(
      seasonId: map['seasonId'] ?? '',
      seasonName: map['seasonName'] ?? '',
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      verifiedReviews: (map['verifiedReviews'] as num?)?.toInt() ?? 0,
      competitionScore: (map['competitionScore'] as num?)?.toDouble() ?? 0.0,
      awardedBadge: map['awardedBadge'] ?? 'NONE',
      subjectBadges: parsedSubjectBadges,
      ruleVersion: map['ruleVersion'] ?? AlgorithmConfig.currentRuleVersion,
      finalizedAt:
          (map['finalizedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'seasonId': seasonId,
      'seasonName': seasonName,
      'averageRating': averageRating,
      'verifiedReviews': verifiedReviews,
      'competitionScore': competitionScore,
      'awardedBadge': awardedBadge,
      'subjectBadges': subjectBadges,
      'ruleVersion': ruleVersion,
      'finalizedAt': Timestamp.fromDate(finalizedAt),
    };
  }

  @override
  List<Object?> get props => [
        seasonId,
        seasonName,
        averageRating,
        verifiedReviews,
        competitionScore,
        awardedBadge,
        subjectBadges,
        ruleVersion,
        finalizedAt,
      ];
}

class RatingSummaryModel extends Equatable {
  final String teacherId;
  final double averageRating;
  final int totalReviews;
  final int totalRatings;
  final int verifiedReviewsCount;
  final double competitionScore;
  final String currentSeasonId;
  final double currentSeasonAverageRating;
  final int currentSeasonVerifiedReviews;
  final double currentSeasonCompetitionScore;
  final String currentBadge;
  final bool isVerifiedBadge;
  final bool isGoldenBadge;
  final bool isMostImproved;
  final String eligibilityStatus;
  final Map<String, dynamic> badgeEligibilityDetails;
  final Map<int, int> starDistribution;
  final Map<String, double> categoryAverages;
  final Map<String, SubjectRatingSummary> subjectSummaries;
  final List<SeasonHistoryRecord> seasonHistory;
  final String ruleVersion;
  final DateTime lastUpdated;

  const RatingSummaryModel({
    required this.teacherId,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.totalRatings = 0,
    int? verifiedReviewsCount,
    this.competitionScore = 0.0,
    this.currentSeasonId = '',
    this.currentSeasonAverageRating = 0.0,
    this.currentSeasonVerifiedReviews = 0,
    this.currentSeasonCompetitionScore = 0.0,
    this.currentBadge = 'NONE',
    this.isVerifiedBadge = false,
    this.isGoldenBadge = false,
    this.isMostImproved = false,
    this.eligibilityStatus = AlgorithmConfig.insufficientEvidenceText,
    this.badgeEligibilityDetails = const {},
    this.starDistribution = const {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
    this.categoryAverages = const {
      'teaching': 0.0,
      'behaviour': 0.0,
      'communication': 0.0,
      'knowledge': 0.0,
      'punctuality': 0.0,
    },
    this.subjectSummaries = const {},
    this.seasonHistory = const [],
    this.ruleVersion = AlgorithmConfig.currentRuleVersion,
    required this.lastUpdated,
  }) : verifiedReviewsCount = verifiedReviewsCount ?? totalRatings;

  bool get hasVerifiedReviews => verifiedReviewsCount > 0;

  String get publicRatingDisplay => hasVerifiedReviews
      ? averageRating.toStringAsFixed(1)
      : AlgorithmConfig.noRatingDisplayText;

  String get currentSeasonRatingDisplay => currentSeasonVerifiedReviews > 0
      ? currentSeasonAverageRating.toStringAsFixed(1)
      : AlgorithmConfig.noRatingDisplayText;

  factory RatingSummaryModel.initial(String teacherId) {
    return RatingSummaryModel(
      teacherId: teacherId,
      averageRating: 0.0,
      totalReviews: 0,
      totalRatings: 0,
      verifiedReviewsCount: 0,
      competitionScore: 0.0,
      currentSeasonId: SeasonModel.current().id,
      currentSeasonAverageRating: 0.0,
      currentSeasonVerifiedReviews: 0,
      currentSeasonCompetitionScore: 0.0,
      currentBadge: 'NONE',
      isVerifiedBadge: false,
      isGoldenBadge: false,
      isMostImproved: false,
      eligibilityStatus: AlgorithmConfig.insufficientEvidenceText,
      badgeEligibilityDetails: const {},
      starDistribution: const {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      categoryAverages: const {
        'teaching': 0.0,
        'behaviour': 0.0,
        'communication': 0.0,
        'knowledge': 0.0,
        'punctuality': 0.0,
      },
      subjectSummaries: const {},
      seasonHistory: const [],
      ruleVersion: AlgorithmConfig.currentRuleVersion,
      lastUpdated: DateTime.now(),
    );
  }

  factory RatingSummaryModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return RatingSummaryModel.fromMap(map, doc.id);
  }

  factory RatingSummaryModel.fromMap(Map<String, dynamic> map, String docId) {
    final starMapRaw = map['starDistribution'] as Map<String, dynamic>? ?? {};
    final starDistribution = <int, int>{
      5: (starMapRaw['5'] as num?)?.toInt() ?? 0,
      4: (starMapRaw['4'] as num?)?.toInt() ?? 0,
      3: (starMapRaw['3'] as num?)?.toInt() ?? 0,
      2: (starMapRaw['2'] as num?)?.toInt() ?? 0,
      1: (starMapRaw['1'] as num?)?.toInt() ?? 0,
    };

    final catMapRaw = map['categoryAverages'] as Map<String, dynamic>? ?? {};
    final categoryAverages = <String, double>{
      'teaching': (catMapRaw['teaching'] as num?)?.toDouble() ??
          (catMapRaw['teaching_quality'] as num?)?.toDouble() ??
          0.0,
      'behaviour': (catMapRaw['behaviour'] as num?)?.toDouble() ?? 0.0,
      'communication': (catMapRaw['communication'] as num?)?.toDouble() ?? 0.0,
      'knowledge': (catMapRaw['knowledge'] as num?)?.toDouble() ?? 0.0,
      'punctuality': (catMapRaw['punctuality'] as num?)?.toDouble() ?? 0.0,
    };

    final rawSubjects = map['subjectSummaries'] as Map<String, dynamic>? ?? {};
    final parsedSubjects = <String, SubjectRatingSummary>{};
    rawSubjects.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        parsedSubjects[key] = SubjectRatingSummary.fromMap(value, key);
      }
    });

    final rawHistory = map['seasonHistory'] as List<dynamic>? ?? [];
    final parsedHistory = rawHistory
        .whereType<Map<String, dynamic>>()
        .map((item) => SeasonHistoryRecord.fromMap(item))
        .toList();

    final parsedTotalRatings = (map['totalRatings'] as num?)?.toInt() ?? 0;
    final parsedVerifiedCount =
        (map['verifiedReviewsCount'] as num?)?.toInt() ?? parsedTotalRatings;

    return RatingSummaryModel(
      teacherId: docId.isNotEmpty ? docId : (map['teacherId'] ?? ''),
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (map['totalReviews'] as num?)?.toInt() ?? 0,
      totalRatings: parsedTotalRatings,
      verifiedReviewsCount: parsedVerifiedCount,
      competitionScore: (map['competitionScore'] as num?)?.toDouble() ?? 0.0,
      currentSeasonId:
          map['currentSeasonId'] ?? SeasonModel.current().id,
      currentSeasonAverageRating:
          (map['currentSeasonAverageRating'] as num?)?.toDouble() ?? 0.0,
      currentSeasonVerifiedReviews:
          (map['currentSeasonVerifiedReviews'] as num?)?.toInt() ?? 0,
      currentSeasonCompetitionScore:
          (map['currentSeasonCompetitionScore'] as num?)?.toDouble() ?? 0.0,
      currentBadge: map['currentBadge'] ?? 'NONE',
      isVerifiedBadge: map['isVerifiedBadge'] ?? false,
      isGoldenBadge: map['isGoldenBadge'] ?? false,
      isMostImproved: map['isMostImproved'] ?? false,
      eligibilityStatus:
          map['eligibilityStatus'] ?? AlgorithmConfig.insufficientEvidenceText,
      badgeEligibilityDetails: Map<String, dynamic>.from(
          map['badgeEligibilityDetails'] as Map? ?? {}),
      starDistribution: starDistribution,
      categoryAverages: categoryAverages,
      subjectSummaries: parsedSubjects,
      seasonHistory: parsedHistory,
      ruleVersion: map['ruleVersion'] ?? AlgorithmConfig.currentRuleVersion,
      lastUpdated:
          (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final serializedSubjects = <String, dynamic>{};
    subjectSummaries.forEach((key, value) {
      serializedSubjects[key] = value.toMap();
    });

    return {
      'teacherId': teacherId,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'totalRatings': totalRatings,
      'verifiedReviewsCount': verifiedReviewsCount,
      'competitionScore': competitionScore,
      'currentSeasonId': currentSeasonId,
      'currentSeasonAverageRating': currentSeasonAverageRating,
      'currentSeasonVerifiedReviews': currentSeasonVerifiedReviews,
      'currentSeasonCompetitionScore': currentSeasonCompetitionScore,
      'currentBadge': currentBadge,
      'isVerifiedBadge': isVerifiedBadge,
      'isGoldenBadge': isGoldenBadge,
      'isMostImproved': isMostImproved,
      'eligibilityStatus': eligibilityStatus,
      'badgeEligibilityDetails': badgeEligibilityDetails,
      'starDistribution': {
        '5': starDistribution[5] ?? 0,
        '4': starDistribution[4] ?? 0,
        '3': starDistribution[3] ?? 0,
        '2': starDistribution[2] ?? 0,
        '1': starDistribution[1] ?? 0,
      },
      'categoryAverages': categoryAverages,
      'subjectSummaries': serializedSubjects,
      'seasonHistory': seasonHistory.map((e) => e.toMap()).toList(),
      'ruleVersion': ruleVersion,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  RatingSummaryModel copyWith({
    String? teacherId,
    double? averageRating,
    int? totalReviews,
    int? totalRatings,
    int? verifiedReviewsCount,
    double? competitionScore,
    String? currentSeasonId,
    double? currentSeasonAverageRating,
    int? currentSeasonVerifiedReviews,
    double? currentSeasonCompetitionScore,
    String? currentBadge,
    bool? isVerifiedBadge,
    bool? isGoldenBadge,
    bool? isMostImproved,
    String? eligibilityStatus,
    Map<String, dynamic>? badgeEligibilityDetails,
    Map<int, int>? starDistribution,
    Map<String, double>? categoryAverages,
    Map<String, SubjectRatingSummary>? subjectSummaries,
    List<SeasonHistoryRecord>? seasonHistory,
    String? ruleVersion,
    DateTime? lastUpdated,
  }) {
    return RatingSummaryModel(
      teacherId: teacherId ?? this.teacherId,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      totalRatings: totalRatings ?? this.totalRatings,
      verifiedReviewsCount: verifiedReviewsCount ?? this.verifiedReviewsCount,
      competitionScore: competitionScore ?? this.competitionScore,
      currentSeasonId: currentSeasonId ?? this.currentSeasonId,
      currentSeasonAverageRating:
          currentSeasonAverageRating ?? this.currentSeasonAverageRating,
      currentSeasonVerifiedReviews:
          currentSeasonVerifiedReviews ?? this.currentSeasonVerifiedReviews,
      currentSeasonCompetitionScore:
          currentSeasonCompetitionScore ?? this.currentSeasonCompetitionScore,
      currentBadge: currentBadge ?? this.currentBadge,
      isVerifiedBadge: isVerifiedBadge ?? this.isVerifiedBadge,
      isGoldenBadge: isGoldenBadge ?? this.isGoldenBadge,
      isMostImproved: isMostImproved ?? this.isMostImproved,
      eligibilityStatus: eligibilityStatus ?? this.eligibilityStatus,
      badgeEligibilityDetails:
          badgeEligibilityDetails ?? this.badgeEligibilityDetails,
      starDistribution: starDistribution ?? this.starDistribution,
      categoryAverages: categoryAverages ?? this.categoryAverages,
      subjectSummaries: subjectSummaries ?? this.subjectSummaries,
      seasonHistory: seasonHistory ?? this.seasonHistory,
      ruleVersion: ruleVersion ?? this.ruleVersion,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
        teacherId,
        averageRating,
        totalReviews,
        totalRatings,
        verifiedReviewsCount,
        competitionScore,
        currentSeasonId,
        currentSeasonAverageRating,
        currentSeasonVerifiedReviews,
        currentSeasonCompetitionScore,
        currentBadge,
        isVerifiedBadge,
        isGoldenBadge,
        isMostImproved,
        eligibilityStatus,
        badgeEligibilityDetails,
        starDistribution,
        categoryAverages,
        subjectSummaries,
        seasonHistory,
        ruleVersion,
        lastUpdated,
      ];
}
