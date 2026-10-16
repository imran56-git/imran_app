import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/rating_summary_model.dart';

class RecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getRecommendedTeachers({
    required String subject,
    required String academicLevel,
    String? location,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('teachers');

      if (subject.isNotEmpty && subject.toLowerCase() != 'general') {
        query = query.where('subjects', arrayContains: subject.toLowerCase());
      }

      if (location != null && location.isNotEmpty) {
        query = query.where('location', isEqualTo: location);
      }

      final querySnapshot = await query.limit(100).get();
      final List<Map<String, dynamic>> teachers = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        final summaryDoc = await _firestore
            .collection('teacher_rating_summary')
            .doc(doc.id)
            .get();

        double competitionScore = 0.0;
        double averageRating = 0.0;
        int reviewCount = 0;
        String badge = 'NONE';

        if (summaryDoc.exists && summaryDoc.data() != null) {
          final summary = RatingSummaryModel.fromFirestore(summaryDoc);
          competitionScore = summary.competitionScore;
          averageRating = summary.averageRating;
          reviewCount = summary.verifiedReviewsCount;
          badge = summary.currentBadge;

          if (subject.isNotEmpty &&
              summary.subjectSummaries.containsKey(subject.toLowerCase())) {
            final subSummary = summary.subjectSummaries[subject.toLowerCase()]!;
            competitionScore = subSummary.competitionScore;
            averageRating = subSummary.averageRating;
            reviewCount = subSummary.verifiedReviews;
            badge = subSummary.awardedBadge;
          }
        }

        double newTeacherBoost = reviewCount < 5 ? 0.2 : 0.0;
        double matchScore = (competitionScore * 0.6) +
            (averageRating * 0.3) +
            (reviewCount > 0 ? 0.1 : 0.0) +
            newTeacherBoost;

        data['matchScore'] = double.parse(matchScore.toStringAsFixed(2));
        data['computedCompetitionScore'] = competitionScore;
        data['computedAverageRating'] = averageRating;
        data['computedReviewCount'] = reviewCount;
        data['computedBadge'] = badge;

        teachers.add(data);
      }

      teachers.sort((a, b) =>
          (b['matchScore'] as double).compareTo(a['matchScore'] as double));

      if (teachers.length > limit) {
        return teachers.sublist(0, limit);
      }
      return teachers;
    } catch (e) {
      debugPrint("Error fetching recommended teachers: $e");
      return [];
    }
  }
}
