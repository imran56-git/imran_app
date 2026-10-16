import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/algorithm_config.dart';
import '../models/follow_model.dart';
import '../models/season_model.dart';

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

      if (teacherId == studentId) {
        return {
          'isValid': false,
          'status': 'rejected',
          'reason': 'Self-review is strictly prohibited.',
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
          'reason': 'Only connected students whose request was accepted can rate this teacher.',
        };
      }

      final followModel =
          FollowModel.fromMap(connectionDoc.data()!, connectionDoc.id);

      if (!followModel.isEligibleToRate) {
        return {
          'isValid': false,
          'status': 'rejected',
          'reason': 'Your follow request has not been accepted by the teacher yet.',
        };
      }

      final currentSeasonId = SeasonModel.current().id;

      final existingReviewsQuery = await _firestore
          .collection('teacher_reviews')
          .where('teacherId', isEqualTo: teacherId)
          .where('studentId', isEqualTo: studentId)
          .where('seasonId', isEqualTo: currentSeasonId)
          .get();

      if (existingReviewsQuery.docs.isNotEmpty &&
          !AlgorithmConfig.allowRatingUpdatesWithinSeason) {
        return {
          'isValid': false,
          'status': 'rejected',
          'reason': 'You have already submitted a review for this teacher in the current season.',
        };
      }

      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final recentBurstQuery = await _firestore
          .collection('teacher_reviews')
          .where('teacherId', isEqualTo: teacherId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();

      bool isFlagged = false;
      String? flagReason;

      if (recentBurstQuery.docs.length >=
          AlgorithmConfig.suspiciousBurstReviewCountInOneHour) {
        isFlagged = true;
        flagReason =
            'Unusually high rating velocity detected within 1 hour; queued for manual verification.';
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

  Future<bool> submitTeacherAppeal({
    required String teacherId,
    required String reviewId,
    required String appealReason,
  }) async {
    try {
      await _firestore.collection('rating_appeals').add({
        'teacherId': teacherId,
        'reviewId': reviewId,
        'appealReason': appealReason,
        'status': 'pending_investigation',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
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
        'ruleVersion': AlgorithmConfig.currentRuleVersion,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
