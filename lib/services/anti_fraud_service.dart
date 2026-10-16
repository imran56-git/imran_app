import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/algorithm_config.dart';
import '../models/review_model.dart';
import '../models/follow_model.dart';

class AntiFraudService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> validateAndProcessReview({
    required String teacherId,
    required String studentId,
    required String connectionId,
    required String subjectId,
    required double stars,
    required String reviewText,
  }) async {
    try {
      if (teacherId.isEmpty || studentId.isEmpty) {
        return {
          'isValid': false,
          'status': 'rejected',
          'reason': 'Invalid teacher or student identification.',
        };
      }

      if (stars < AlgorithmConfig.minAllowedRating ||
          stars > AlgorithmConfig.maxAllowedRating) {
        return {
          'isValid': false,
          'status': 'rejected',
          'reason': 'Rating stars must be between 1.0 and 5.0.',
        };
      }

      String resolvedConnectionId = connectionId;
      if (resolvedConnectionId.isEmpty) {
        resolvedConnectionId = '${teacherId}_$studentId';
      }

      final connectionDoc = await _firestore
          .collection('follow_requests')
          .doc(resolvedConnectionId)
          .get();

      if (!connectionDoc.exists || connectionDoc.data() == null) {
        return {
          'isValid': false,
          'status': 'rejected',
          'reason': 'No established Student-Teacher connection found.',
        };
      }

      final followModel = FollowModel.fromMap(connectionDoc.data()!, connectionDoc.id);

      if (!followModel.isEligibleToRate) {
        return {
          'isValid': false,
          'status': 'rejected',
          'reason': 'Student-Teacher connection is not accepted or ineligible.',
        };
      }

      final currentSeasonId = ReviewModel.getCurrentSeasonId(DateTime.now());

      final existingReviewsQuery = await _firestore
          .collection('reviews')
          .where('teacherId', isEqualTo: teacherId)
          .where('studentId', isEqualTo: studentId)
          .where('seasonId', isEqualTo: currentSeasonId)
          .get();

      if (existingReviewsQuery.docs.isNotEmpty) {
        if (!AlgorithmConfig.allowRatingUpdatesWithinSeason) {
          return {
            'isValid': false,
            'status': 'rejected',
            'reason': 'You have already submitted a review for this teacher in the current season.',
          };
        }
      }

      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final recentBurstQuery = await _firestore
          .collection('reviews')
          .where('teacherId', isEqualTo: teacherId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();

      bool isFlagged = false;
      String? flagReason;

      if (recentBurstQuery.docs.length >= AlgorithmConfig.suspiciousBurstReviewCountInOneHour) {
        isFlagged = true;
        flagReason = 'Unusually high rating frequency detected in a short time window.';
      }

      final status = isFlagged ? 'flagged' : 'verified';
      final isVerified = !isFlagged;

      return {
        'isValid': true,
        'status': status,
        'isVerified': isVerified,
        'flagReason': flagReason,
        'connectionId': resolvedConnectionId,
        'seasonId': currentSeasonId,
      };
    } catch (e) {
      return {
        'isValid': false,
        'status': 'rejected',
        'reason': 'Error during anti-fraud validation: $e',
      };
    }
  }

  Future<void> logAuditTrail({
    required String reviewId,
    required String teacherId,
    required String studentId,
    required String status,
    required String reason,
  }) async {
    try {
      await _firestore.collection('review_audit_logs').add({
        'reviewId': reviewId,
        'teacherId': teacherId,
        'studentId': studentId,
        'status': status,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
