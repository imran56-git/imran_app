import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/algorithm_config.dart';
import '../models/rating_summary_model.dart';
import '../models/review_model.dart';
import '../models/season_model.dart';

class CompetitionEngineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double calculateBayesianScore({
    required double averageRatingR,
    required int verifiedReviewsV,
    double? groupAverageC,
    int? priorStrengthM,
  }) {
    if (verifiedReviewsV <= 0) {
      return 0.0;
    }
    final int m = priorStrengthM ?? AlgorithmConfig.bayesianPriorStrengthM;
    final double c = groupAverageC ?? AlgorithmConfig.defaultSubjectGroupAverageC;

    final double score =
        ((verifiedReviewsV * averageRatingR) + (m * c)) / (verifiedReviewsV + m);
    return double.parse(score.toStringAsFixed(2));
  }

  String getEvidenceTierStatus(int verifiedReviews) {
    if (verifiedReviews <= AlgorithmConfig.tierInsufficientMaxReviews) {
      return AlgorithmConfig.insufficientEvidenceText;
    } else if (verifiedReviews < AlgorithmConfig.tierLimitedCompMinReviews) {
      return 'Preliminary Evaluation — More Reviews Needed for Top Tiers';
    } else if (verifiedReviews < AlgorithmConfig.tierFullCompMinReviews) {
      return 'Eligible for M Badge Tier — Need ${AlgorithmConfig.tierFullCompMinReviews}+ for B/K Tiers';
    } else {
      return 'Eligible for Full Competition Evaluation';
    }
  }

  Map<String, dynamic> evaluateBadgeQualification({
    required double publicAverageRating,
    required int verifiedReviews,
    required double competitionScore,
    bool isSubjectEvaluated = true,
  }) {
    final bool meetsKRating =
        publicAverageRating >= AlgorithmConfig.kBadgeMinPublicRating;
    final bool meetsKReviews =
        verifiedReviews >= AlgorithmConfig.kBadgeMinVerifiedReviews;
    final bool meetsKComp =
        competitionScore >= AlgorithmConfig.kBadgeMinCompetitionScore;

    final bool meetsBRating =
        publicAverageRating >= AlgorithmConfig.bBadgeMinPublicRating;
    final bool meetsBReviews =
        verifiedReviews >= AlgorithmConfig.bBadgeMinVerifiedReviews;
    final bool meetsBComp =
        competitionScore >= AlgorithmConfig.bBadgeMinCompetitionScore;

    final bool meetsMRating =
        publicAverageRating >= AlgorithmConfig.mBadgeMinPublicRating;
    final bool meetsMReviews =
        verifiedReviews >= AlgorithmConfig.mBadgeMinVerifiedReviews;
    final bool meetsMComp =
        competitionScore >= AlgorithmConfig.mBadgeMinCompetitionScore;

    String awardedBadge = 'NONE';
    if (isSubjectEvaluated && meetsKRating && meetsKReviews && meetsKComp) {
      awardedBadge = 'K';
    } else if (isSubjectEvaluated && meetsBRating && meetsBReviews && meetsBComp) {
      awardedBadge = 'B';
    } else if (isSubjectEvaluated && meetsMRating && meetsMReviews && meetsMComp) {
      awardedBadge = 'M';
    }

    return {
      'awardedBadge': awardedBadge,
      'eligibilityStatus': getEvidenceTierStatus(verifiedReviews),
      'kBadgeCheck': {
        'requiredRatingMet': meetsKRating,
        'minimumVerifiedReviewsMet': meetsKReviews,
        'competitionScoreMet': meetsKComp,
        'subjectEvidenceComplete': isSubjectEvaluated,
      },
      'bBadgeCheck': {
        'requiredRatingMet': meetsBRating,
        'minimumVerifiedReviewsMet': meetsBReviews,
        'competitionScoreMet': meetsBComp,
        'subjectEvidenceComplete': isSubjectEvaluated,
      },
      'mBadgeCheck': {
        'requiredRatingMet': meetsMRating,
        'minimumVerifiedReviewsMet': meetsMReviews,
        'competitionScoreMet': meetsMComp,
        'subjectEvidenceComplete': isSubjectEvaluated,
      },
    };
  }

  bool evaluateGoldenBadge({
    required DateTime? registrationDate,
    bool isAccountActive = true,
  }) {
    if (registrationDate == null || !isAccountActive) {
      return false;
    }
    final daysOnPlatform = DateTime.now().difference(registrationDate).inDays;
    return daysOnPlatform >= AlgorithmConfig.goldenBadgeRequiredDays;
  }

  bool evaluateVerifiedBadge({
    required bool isIdentityAndProfileVerified,
  }) {
    if (AlgorithmConfig.requireActualVerificationForVerifiedBadge) {
      return isIdentityAndProfileVerified;
    }
    return isIdentityAndProfileVerified;
  }

  bool evaluateMostImproved({
    required double previousSeasonRating,
    required int previousSeasonVerifiedReviews,
    required double currentSeasonRating,
    required int currentSeasonVerifiedReviews,
  }) {
    if (previousSeasonVerifiedReviews <
            AlgorithmConfig.mostImprovedMinReviewsPerSeason ||
        currentSeasonVerifiedReviews <
            AlgorithmConfig.mostImprovedMinReviewsPerSeason) {
      return false;
    }

    final prevBayesian = calculateBayesianScore(
      averageRatingR: previousSeasonRating,
      verifiedReviewsV: previousSeasonVerifiedReviews,
    );
    final currBayesian = calculateBayesianScore(
      averageRatingR: currentSeasonRating,
      verifiedReviewsV: currentSeasonVerifiedReviews,
    );

    final improvement = currBayesian - prevBayesian;
    return improvement >= AlgorithmConfig.mostImprovedMinRatingJump;
  }

  int getBadgePriorityScore(String badge) {
    switch (badge.toUpperCase()) {
      case 'K':
        return 400;
      case 'B':
        return 300;
      case 'M':
        return 200;
      case 'GOLDEN':
        return 150;
      case 'VERIFIED':
        return 100;
      default:
        return 0;
    }
  }

  Future<RatingSummaryModel> computeFullTeacherEvaluation({
    required String teacherId,
    required List<ReviewModel> allVerifiedReviews,
    List<SeasonHistoryRecord> existingHistory = const [],
    bool isIdentityVerified = false,
    DateTime? teacherCreatedAt,
  }) async {
    final currentSeason = SeasonModel.current();
    final currentSeasonId = currentSeason.id;

    final eligibleReviews = allVerifiedReviews
        .where((r) => r.isEligibleForCalculation)
        .toList();

    final isVerifiedBadge = evaluateVerifiedBadge(
      isIdentityAndProfileVerified: isIdentityVerified,
    );
    final isGoldenBadge = evaluateGoldenBadge(
      registrationDate: teacherCreatedAt,
    );

    if (eligibleReviews.isEmpty) {
      return RatingSummaryModel.initial(teacherId).copyWith(
        currentSeasonId: currentSeasonId,
        isVerifiedBadge: isVerifiedBadge,
        isGoldenBadge: isGoldenBadge,
        seasonHistory: existingHistory,
        lastUpdated: DateTime.now(),
      );
    }

    double allTimeStars = 0.0;
    final starDist = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    double sumTeaching = 0.0;
    double sumBehaviour = 0.0;
    double sumCommunication = 0.0;
    double sumKnowledge = 0.0;
    double sumPunctuality = 0.0;

    final List<ReviewModel> currentSeasonReviews = [];
    final Map<String, List<ReviewModel>> subjectReviewsMap = {};

    for (final r in eligibleReviews) {
      allTimeStars += r.overallRating;
      final starBucket = r.overallRating.round().clamp(1, 5);
      starDist[starBucket] = (starDist[starBucket] ?? 0) + 1;

      sumTeaching += r.categories.teaching;
      sumBehaviour += r.categories.behaviour;
      sumCommunication += r.categories.communication;
      sumKnowledge += r.categories.knowledge;
      sumPunctuality += r.categories.punctuality;

      if (r.seasonId == currentSeasonId) {
        currentSeasonReviews.add(r);
      }

      final subKey = r.subjectId.trim().isNotEmpty ? r.subjectId.trim() : 'general';
      subjectReviewsMap.putIfAbsent(subKey, () => []).add(r);
    }

    final totalCount = eligibleReviews.length;
    final allTimeAvg =
        double.parse((allTimeStars / totalCount).toStringAsFixed(2));
    final allTimeCompScore = calculateBayesianScore(
      averageRatingR: allTimeAvg,
      verifiedReviewsV: totalCount,
    );

    double seasonStars = 0.0;
    for (final sr in currentSeasonReviews) {
      seasonStars += sr.overallRating;
    }
    final seasonCount = currentSeasonReviews.length;
    final seasonAvg = seasonCount > 0
        ? double.parse((seasonStars / seasonCount).toStringAsFixed(2))
        : 0.0;
    final seasonCompScore = calculateBayesianScore(
      averageRatingR: seasonAvg,
      verifiedReviewsV: seasonCount,
    );

    final categoryAverages = <String, double>{
      'teaching': double.parse((sumTeaching / totalCount).toStringAsFixed(1)),
      'behaviour': double.parse((sumBehaviour / totalCount).toStringAsFixed(1)),
      'communication':
          double.parse((sumCommunication / totalCount).toStringAsFixed(1)),
      'knowledge': double.parse((sumKnowledge / totalCount).toStringAsFixed(1)),
      'punctuality':
          double.parse((sumPunctuality / totalCount).toStringAsFixed(1)),
    };

    final Map<String, SubjectRatingSummary> subjectSummaries = {};
    String highestSubjectBadge = 'NONE';

    subjectReviewsMap.forEach((subId, subReviews) {
      double subTotal = 0.0;
      for (final sr in subReviews) {
        subTotal += sr.overallRating;
      }
      final subCount = subReviews.length;
      final subAvg = double.parse((subTotal / subCount).toStringAsFixed(2));
      final subComp = calculateBayesianScore(
        averageRatingR: subAvg,
        verifiedReviewsV: subCount,
      );

      final subEval = evaluateBadgeQualification(
        publicAverageRating: subAvg,
        verifiedReviews: subCount,
        competitionScore: subComp,
        isSubjectEvaluated: true,
      );

      final subBadge = subEval['awardedBadge'] as String;
      if (getBadgePriorityScore(subBadge) >
          getBadgePriorityScore(highestSubjectBadge)) {
        highestSubjectBadge = subBadge;
      }

      subjectSummaries[subId] = SubjectRatingSummary(
        subjectId: subId,
        subjectName: subId,
        averageRating: subAvg,
        verifiedReviews: subCount,
        competitionScore: subComp,
        awardedBadge: subBadge,
        eligibilityStatus: subEval['eligibilityStatus'] as String,
        isSubjectVerified: true,
      );
    });

    final seasonEval = evaluateBadgeQualification(
      publicAverageRating: seasonAvg,
      verifiedReviews: seasonCount,
      competitionScore: seasonCompScore,
      isSubjectEvaluated: true,
    );

    String activeBadge = seasonEval['awardedBadge'] as String;
    if (activeBadge == 'NONE' && highestSubjectBadge != 'NONE') {
      activeBadge = highestSubjectBadge;
    }

    bool improved = false;
    if (existingHistory.isNotEmpty) {
      final lastRecord = existingHistory.last;
      improved = evaluateMostImproved(
        previousSeasonRating: lastRecord.averageRating,
        previousSeasonVerifiedReviews: lastRecord.verifiedReviews,
        currentSeasonRating: seasonAvg,
        currentSeasonVerifiedReviews: seasonCount,
      );
    }

    final summary = RatingSummaryModel(
      teacherId: teacherId,
      averageRating: allTimeAvg,
      totalReviews: totalCount,
      totalRatings: totalCount,
      verifiedReviewsCount: totalCount,
      competitionScore: allTimeCompScore,
      currentSeasonId: currentSeasonId,
      currentSeasonAverageRating: seasonAvg,
      currentSeasonVerifiedReviews: seasonCount,
      currentSeasonCompetitionScore: seasonCompScore,
      currentBadge: activeBadge,
      isVerifiedBadge: isVerifiedBadge,
      isGoldenBadge: isGoldenBadge,
      isMostImproved: improved,
      eligibilityStatus: seasonEval['eligibilityStatus'] as String,
      badgeEligibilityDetails: seasonEval,
      starDistribution: starDist,
      categoryAverages: categoryAverages,
      subjectSummaries: subjectSummaries,
      seasonHistory: existingHistory,
      ruleVersion: AlgorithmConfig.currentRuleVersion,
      lastUpdated: DateTime.now(),
    );

    await _firestore
        .collection('teacher_rating_summary')
        .doc(teacherId)
        .set(summary.toMap(), SetOptions(merge: true));

    return summary;
  }
}
