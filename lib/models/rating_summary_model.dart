import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Class representing aggregated rating breakdown & statistical summaries for a teacher.
class RatingSummaryModel extends Equatable {
  final String teacherId;
  final double averageRating;
  final int totalReviews;
  final int totalRatings;
  final Map<int, int> starDistribution; // {5: count, 4: count, 3: count, 2: count, 1: count}
  final Map<String, double> categoryAverages; // {'teaching': 4.8, 'behaviour': 4.9, ...}
  final DateTime lastUpdated;

  const RatingSummaryModel({
    required this.teacherId,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.totalRatings = 0,
    this.starDistribution = const {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
    this.categoryAverages = const {
      'teaching': 0.0,
      'behaviour': 0.0,
      'communication': 0.0,
      'knowledge': 0.0,
      'punctuality': 0.0,
    },
    required this.lastUpdated,
  });

  /// Factory constructor to create default initial model for a teacher
  factory RatingSummaryModel.initial(String teacherId) {
    return RatingSummaryModel(
      teacherId: teacherId,
      averageRating: 0.0,
      totalReviews: 0,
      totalRatings: 0,
      starDistribution: const {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      categoryAverages: const {
        'teaching': 0.0,
        'behaviour': 0.0,
        'communication': 0.0,
        'knowledge': 0.0,
        'punctuality': 0.0,
      },
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
      'teaching': (catMapRaw['teaching'] as num?)?.toDouble() ?? 0.0,
      'behaviour': (catMapRaw['behaviour'] as num?)?.toDouble() ?? 0.0,
      'communication': (catMapRaw['communication'] as num?)?.toDouble() ?? 0.0,
      'knowledge': (catMapRaw['knowledge'] as num?)?.toDouble() ?? 0.0,
      'punctuality': (catMapRaw['punctuality'] as num?)?.toDouble() ?? 0.0,
    };

    return RatingSummaryModel(
      teacherId: docId,
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (map['totalReviews'] as num?)?.toInt() ?? 0,
      totalRatings: (map['totalRatings'] as num?)?.toInt() ?? 0,
      starDistribution: starDistribution,
      categoryAverages: categoryAverages,
      lastUpdated: (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'totalRatings': totalRatings,
      'starDistribution': {
        '5': starDistribution[5] ?? 0,
        '4': starDistribution[4] ?? 0,
        '3': starDistribution[3] ?? 0,
        '2': starDistribution[2] ?? 0,
        '1': starDistribution[1] ?? 0,
      },
      'categoryAverages': categoryAverages,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  RatingSummaryModel copyWith({
    String? teacherId,
    double? averageRating,
    int? totalReviews,
    int? totalRatings,
    Map<int, int>? starDistribution,
    Map<String, double>? categoryAverages,
    DateTime? lastUpdated,
  }) {
    return RatingSummaryModel(
      teacherId: teacherId ?? this.teacherId,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      totalRatings: totalRatings ?? this.totalRatings,
      starDistribution: starDistribution ?? this.starDistribution,
      categoryAverages: categoryAverages ?? this.categoryAverages,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
        teacherId,
        averageRating,
        totalReviews,
        totalRatings,
        starDistribution,
        categoryAverages,
        lastUpdated,
      ];
}
