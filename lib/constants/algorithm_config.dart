/// FYBTT — Find Your Best Teacher Today
/// Centralized Algorithm, Season, Badge & Anti-Fraud Configuration
/// Rule Version: 2.0.0 (6-Month Bi-Annual Season Model)

class AlgorithmConfig {
  // প্রাইভেট কনস্ট্রাক্টর যাতে কেউ ভুল করে অবজেক্ট তৈরি না করে
  AlgorithmConfig._();

  // ===========================================================================
  // ১. অ্যালগরিদম রুল ভার্সনিং (Rule Versioning for Historical Integrity)
  // ===========================================================================
  /// ভবিষ্যতে নিয়ম বদলালেও পুরনো সিজনের ব্যাজগুলো যেন সেই সময়ের নিয়ম অনুযায়ীই থাকে
  static const String currentRuleVersion = 'v2.0.0_6m_bayesian';

  // ===========================================================================
  // ২. সিজন কনফিগারেশন (6-Month Bi-Annual Season Policy)
  // ===========================================================================
  /// বছরে ২টি সিজন হবে, প্রতিটি ৬ মাস করে (আগের ৩ মাসের ৪টি সিজনের পরিবর্তে)
  static const int seasonsPerYear = 2;
  static const int seasonDurationMonths = 6;

  /// সিজন ১: জানুয়ারি ১ থেকে জুন ৩০
  static const int season1StartMonth = 1;
  static const int season1EndMonth = 6;

  /// সিজন ২: জুলাই ১ থেকে ডিসেম্বর ৩১
  static const int season2StartMonth = 7;
  static const int season2EndMonth = 12;

  // ===========================================================================
  // ৩. রেটিং এবং রিভিউ পলিসি (Rating & Eligibility Policy)
  // ===========================================================================
  /// একজন কানেক্টেড স্টুডেন্ট প্রতি সিজনে একজন টিচারকে ১টি মাত্র অ্যাক্টিভ রিভিউ দিতে পারবে
  static const int maxActiveReviewsPerStudentPerSeason = 1;

  /// স্টুডেন্ট কি চলতি সিজনের ভেতর তার দেওয়া রেটিং আপডেট (Modify) করতে পারবে?
  /// (আপডেট করলে পুরনো রেকর্ডই আপডেট হবে, নতুন রিভিউ হিসেবে কাউন্ট হবে না)
  static const bool allowRatingUpdatesWithinSeason = true;

  /// রেটিং দেওয়ার জন্য স্টুডেন্ট-টিচার ফলো রিকোয়েস্ট 'accepted' হওয়া বাধ্যতামূলক
  static const bool requireAcceptedConnectionForRating = true;

  /// অফলাইনে টিউশন ফি দেওয়া স্টুডেন্টরাও রেটিং দিতে পারবে (অনলাইন পেমেন্ট বাধ্যতামূলক নয়)
  static const bool requireOnlinePaymentForRating = false;

  /// রেটিং স্কেল (১ থেকে ৫ স্টার)
  static const double minAllowedRating = 1.0;
  static const double maxAllowedRating = 5.0;

  /// জিরো রিভিউ থাকলে প্রোফাইলে ০.০ না দেখিয়ে যা দেখানো হবে
  static const String noRatingDisplayText = 'Not Rated Yet';

  // ===========================================================================
  // ৪. পারফরম্যান্স ব্রেকডাউন ক্যাটাগরি (5 Performance Breakdown Categories)
  // ===========================================================================
  static const List<String> performanceCategories = [
    'teaching_quality', // Teaching Quality
    'behaviour',        // Behaviour
    'communication',    // Communication
    'knowledge',        // Knowledge
    'punctuality',      // Punctuality
  ];

  /// প্রাথমিক অবস্থায় ৫টি ক্যাটাগরির গুরুত্ব (Weight) সমান রাখা হয়েছে (২০% করে)
  static const Map<String, double> categoryWeights = {
    'teaching_quality': 0.20,
    'behaviour': 0.20,
    'communication': 0.20,
    'knowledge': 0.20,
    'punctuality': 0.20,
  };

  // ===========================================================================
  // ৫. বায়েসিয়ান কম্পিটিশন স্কোর (Engine B: Bayesian Rating Parameters)
  // ===========================================================================
  /// ফর্মুলা: Adjusted Score = ((v * R) + (m * C)) / (v + m)
  /// m = Prior Strength (ন্যূনতম কতগুলো রিভিউ থাকলে স্কোরটি পুরোপুরি স্থিতিশীল ধরা হবে)
  static const int bayesianPriorStrengthM = 20;

  /// C = প্ল্যাটফর্ম বা সাবজেক্ট গ্রুপের গড় রেটিং (যতক্ষণ পর্যাপ্ত ডেটা না জমে, ততক্ষণ Provisional গড়)
  static const double defaultSubjectGroupAverageC = 4.2;

  // ===========================================================================
  // ৬. রিভিউ কাউন্ট ও এভিডেন্স থ্রেশহোল্ড (Evidence Tiers)
  // ===========================================================================
  static const int tierInsufficientMaxReviews = 4;   // 0–4: Insufficient evidence
  static const int tierPreliminaryMinReviews = 5;    // 5–9: Preliminary evaluation
  static const int tierLimitedCompMinReviews = 10;   // 10–19: Limited competition tier
  static const int tierFullCompMinReviews = 20;      // 20+: Full competition evaluation

  static const String insufficientEvidenceText =
      'Not Yet Eligible — More Verified Reviews Needed';

  // ===========================================================================
  // ৭. ব্যাজ এলিজিবিলিটি শর্তাবলি (M, B, K, Verified & Golden Badge Rules)
  // ===========================================================================
  
  /// ১. Verified Badge: শুধু ২-৩ দিন পার হলেই হবে না, অ্যাডমিন/সিস্টেম ভেরিফিকেশন সম্পন্ন হতে হবে
  static const bool requireActualVerificationForVerifiedBadge = true;

  /// ২. Golden Badge: প্ল্যাটফর্মে সফলভাবে ৩ বছর (১০৯৫ দিন) পূর্ণ হতে হবে
  static const int goldenBadgeRequiredYears = 3;
  static const int goldenBadgeRequiredDays = 1095;

  /// ৩. M Badge (Master of the Subject)
  static const double mBadgeMinPublicRating = 3.8;
  static const double mBadgeMinCompetitionScore = 3.8;
  static const int mBadgeMinVerifiedReviews = 10; // ন্যূনতম ১০টি সাবজেক্ট-ভিত্তিক ভেরিফায়েড রিভিউ

  /// ৪. B Badge (Best of the Subject)
  static const double bBadgeMinPublicRating = 4.2;
  static const double bBadgeMinCompetitionScore = 4.2;
  static const int bBadgeMinVerifiedReviews = 20; // ন্যূনতম ২০টি সাবজেক্ট-ভিত্তিক ভেরিফায়েড রিভিউ

  /// ৫. K Badge (King of the Subject)
  /// শুধুমাত্র ২টো রিভিউ পেয়ে ৫.০ হলেই King হওয়া যাবে না, পর্যাপ্ত প্রমাণ ও কম্পিটিশন স্কোর লাগবে
  static const double kBadgeMinPublicRating = 4.9;      // ৪.৯ বা ৫.০ আসল গড় রেটিং
  static const double kBadgeMinCompetitionScore = 4.65; // বায়েসিয়ান অ্যাডজাস্টেড স্কোর থ্রেশহোল্ড
  static const int kBadgeMinVerifiedReviews = 30;       // ন্যূনতম ৩০টি সাবজেক্ট-ভিত্তিক ভেরিফায়েড রিভিউ

  /// Most Improved Teacher হওয়ার জন্য আগের সিজন ও বর্তমান সিজনে ন্যূনতম রিভিউ সংখ্যা
  static const int mostImprovedMinReviewsPerSeason = 8;
  static const double mostImprovedMinRatingJump = 0.3; // অন্তত ০.৩ স্টার উন্নতি হতে হবে

  // ===========================================================================
  // ৮. অ্যান্টি-ফ্রড ও ভ্যালিডেশন থ্রেশহোল্ড (Engine A: Anti-Fraud Controls)
  // ===========================================================================
  /// কানেকশন অ্যাকসেপ্ট হওয়ার পর অন্তত কত ঘণ্টা পার হলে রিভিউকে স্বাভাবিক ধরা হবে 
  /// (এর আগে দিলে রিজেক্ট হবে না, শুধু চেক করার জন্য নজরে রাখা হতে পারে)
  static const int minHoursAfterConnectionBeforeReview = 1;

  /// অল্প সময়ের মধ্যে অস্বাভাবিক বেশি রিভিউ আসলে তদন্তের জন্য 'flagged' করার সীমা
  /// (মনে রাখতে হবে: কম রেটিং বা একই ওয়াইফাই/আইপি মানেই অটোমেটিক ফ্রড নয়)
  static const int suspiciousBurstReviewCountInOneHour = 15;

  // ===========================================================================
  // ৯. অটোমেটিক সিজনাল মেসেজ টেমপ্লেট (Automated Seasonal Chat Prompt)
  // ===========================================================================
  static const String seasonRatingMessageType = 'season_rating_prompt';

  /// নতুন সিজন শুরু হলে টিচারের তরফ থেকে কানেক্টেড স্টুডেন্টের কাছে যে গোছানো ইংলিশ মেসেজ যাবে
  static String buildSeasonalRatingPromptMessage({
    required String studentName,
    required String teacherName,
    required String seasonName,
  }) {
    return 'Hello $studentName! 🌟\n\n'
        'A new rating season ($seasonName) has officially started on FYBTT. '
        'Thank you for being a connected student with me ($teacherName). '
        'Your honest feedback helps me improve my teaching and guides other students in choosing the right mentor.\n\n'
        'Please take a moment to rate your learning experience directly from the button below!';
  }
}
