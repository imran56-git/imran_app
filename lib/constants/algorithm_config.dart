class AlgorithmConfig {
  AlgorithmConfig._();

  static const String currentRuleVersion = 'v2.0.0_6m_bayesian';

  static const int seasonsPerYear = 2;
  static const int seasonDurationMonths = 6;

  static const int season1StartMonth = 1;
  static const int season1EndMonth = 6;

  static const int season2StartMonth = 7;
  static const int season2EndMonth = 12;

  static const int maxActiveReviewsPerStudentPerSeason = 1;
  static const bool allowRatingUpdatesWithinSeason = true;
  static const bool requireAcceptedConnectionForRating = true;
  static const bool requireOnlinePaymentForRating = false;

  static const double minAllowedRating = 1.0;
  static const double maxAllowedRating = 5.0;
  static const int maxReviewTextLength = 250;

  static const String noRatingDisplayText = 'Not Rated Yet';

  static const List<String> performanceCategories = [
    'teaching_quality',
    'behaviour',
    'communication',
    'knowledge',
    'punctuality',
  ];

  static const Map<String, double> categoryWeights = {
    'teaching_quality': 0.20,
    'behaviour': 0.20,
    'communication': 0.20,
    'knowledge': 0.20,
    'punctuality': 0.20,
  };

  static const int bayesianPriorStrengthM = 20;
  static const double defaultSubjectGroupAverageC = 4.2;

  static const int tierInsufficientMaxReviews = 4;
  static const int tierPreliminaryMinReviews = 5;
  static const int tierLimitedCompMinReviews = 10;
  static const int tierFullCompMinReviews = 20;

  static const String insufficientEvidenceText =
      'Not Yet Eligible — More Verified Reviews Needed';

  static const bool requireActualVerificationForVerifiedBadge = true;
  static const int goldenBadgeRequiredYears = 3;
  static const int goldenBadgeRequiredDays = 1095;

  static const double mBadgeMinPublicRating = 3.8;
  static const double mBadgeMinCompetitionScore = 3.8;
  static const int mBadgeMinVerifiedReviews = 10;

  static const double bBadgeMinPublicRating = 4.2;
  static const double bBadgeMinCompetitionScore = 4.2;
  static const int bBadgeMinVerifiedReviews = 20;

  static const double kBadgeMinPublicRating = 4.9;
  static const double kBadgeMinCompetitionScore = 4.65;
  static const int kBadgeMinVerifiedReviews = 30;

  static const int mostImprovedMinReviewsPerSeason = 8;
  static const double mostImprovedMinRatingJump = 0.3;

  static const int minHoursAfterConnectionBeforeReview = 1;
  static const int suspiciousBurstReviewCountInOneHour = 15;

  static const String seasonRatingMessageType = 'season_rating_prompt';

  static double calculateBayesianScore({
    required int totalReviews,
    required double averageRating,
    double groupAverage = defaultSubjectGroupAverageC,
    int priorStrength = bayesianPriorStrengthM,
  }) {
    if (totalReviews <= 0) return 0.0;
    final score = ((totalReviews * averageRating) + (priorStrength * groupAverage)) /
        (totalReviews + priorStrength);
    return double.parse(score.toStringAsFixed(2));
  }

  static String resolveSubjectBadge({
    required int verifiedReviewsCount,
    required double publicRating,
    required double competitionScore,
  }) {
    if (verifiedReviewsCount >= kBadgeMinVerifiedReviews &&
        publicRating >= kBadgeMinPublicRating &&
        competitionScore >= kBadgeMinCompetitionScore) {
      return 'K';
    }
    if (verifiedReviewsCount >= bBadgeMinVerifiedReviews &&
        publicRating >= bBadgeMinPublicRating &&
        competitionScore >= bBadgeMinCompetitionScore) {
      return 'B';
    }
    if (verifiedReviewsCount >= mBadgeMinVerifiedReviews &&
        publicRating >= mBadgeMinPublicRating &&
        competitionScore >= mBadgeMinCompetitionScore) {
      return 'M';
    }
    return 'NONE';
  }

  static int getBadgePriority(String badge) {
    switch (badge.toUpperCase()) {
      case 'K':
        return 3;
      case 'B':
        return 2;
      case 'M':
        return 1;
      default:
        return 0;
    }
  }

  static String resolveEligibilityStatus(int verifiedReviewsCount) {
    if (verifiedReviewsCount >= tierLimitedCompMinReviews) {
      return 'Eligible';
    }
    return insufficientEvidenceText;
  }

  static double calculateWeightedRating({
    required double teaching,
    required double behaviour,
    required double communication,
    required double knowledge,
    required double punctuality,
  }) {
    final weightedScore = (teaching * (categoryWeights['teaching_quality'] ?? 0.20)) +
        (behaviour * (categoryWeights['behaviour'] ?? 0.20)) +
        (communication * (categoryWeights['communication'] ?? 0.20)) +
        (knowledge * (categoryWeights['knowledge'] ?? 0.20)) +
        (punctuality * (categoryWeights['punctuality'] ?? 0.20));
    return double.parse(weightedScore.toStringAsFixed(1));
  }

  static bool isValidRating(double rating) {
    return rating >= minAllowedRating && rating <= maxAllowedRating;
  }

  static String buildSeasonalRatingPromptMessage({
    required String studentName,
    required String teacherName,
    required String seasonName,
  }) {
    return 'Hello $studentName!\n\n'
        'A new rating season ($seasonName) has officially started on FYBTT. '
        'Thank you for being a connected student with me ($teacherName). '
        'Your honest feedback helps me improve my teaching and guides other students in choosing the right mentor.\n\n'
        'Please take a moment to rate your learning experience directly from the button below!';
  }
}
