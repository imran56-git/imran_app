import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/rating_summary_model.dart';
import '../models/review_model.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch the real-time rating summary for a teacher
  Stream<RatingSummaryModel> streamTeacherRatingSummary(String teacherId) {
    return _firestore
        .collection('teacher_rating_summary')
        .doc(teacherId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return RatingSummaryModel.fromFirestore(doc);
      }
      return RatingSummaryModel.initial(teacherId);
    });
  }

  /// Get teacher rating summary once
  Future<RatingSummaryModel> getTeacherRatingSummary(String teacherId) async {
    try {
      final doc = await _firestore
          .collection('teacher_rating_summary')
          .doc(teacherId)
          .get();

      if (doc.exists && doc.data() != null) {
        return RatingSummaryModel.fromFirestore(doc);
      }
      return RatingSummaryModel.initial(teacherId);
    } catch (e) {
      debugPrint("Error getting teacher rating summary: $e");
      return RatingSummaryModel.initial(teacherId);
    }
  }

  /// Calculate Category breakdown percentage for UI progress bars
  Map<String, double> calculateCategoryPercentages(RatingSummaryModel summary) {
    if (summary.totalReviews == 0) {
      return {
        'teaching': 0.0,
        'behaviour': 0.0,
        'communication': 0.0,
        'knowledge': 0.0,
        'punctuality': 0.0,
      };
    }

    return {
      'teaching': (summary.categoryAverages['teaching'] ?? 0.0) / 5.0,
      'behaviour': (summary.categoryAverages['behaviour'] ?? 0.0) / 5.0,
      'communication': (summary.categoryAverages['communication'] ?? 0.0) / 5.0,
      'knowledge': (summary.categoryAverages['knowledge'] ?? 0.0) / 5.0,
      'punctuality': (summary.categoryAverages['punctuality'] ?? 0.0) / 5.0,
    };
  }

  /// Calculate Star distribution percentages for chart UI
  Map<int, double> calculateStarPercentages(RatingSummaryModel summary) {
    if (summary.totalReviews == 0) {
      return {5: 0.0, 4: 0.0, 3: 0.0, 2: 0.0, 1: 0.0};
    }

    final total = summary.totalReviews;
    return {
      5: (summary.starDistribution[5] ?? 0) / total,
      4: (summary.starDistribution[4] ?? 0) / total,
      3: (summary.starDistribution[3] ?? 0) / total,
      2: (summary.starDistribution[2] ?? 0) / total,
      1: (summary.starDistribution[1] ?? 0) / total,
    };
  }

  /// Helper to calculate average category rating from raw input
  CategoryRating createCategoryRating({
    required double teaching,
    required double behaviour,
    required double communication,
    required double knowledge,
    required double punctuality,
  }) {
    return CategoryRating(
      teaching: double.parse(teaching.toStringAsFixed(1)),
      behaviour: double.parse(behaviour.toStringAsFixed(1)),
      communication: double.parse(communication.toStringAsFixed(1)),
      knowledge: double.parse(knowledge.toStringAsFixed(1)),
      punctuality: double.parse(punctuality.toStringAsFixed(1)),
    );
  }
}
