import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/algorithm_config.dart';
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
      bool isConnected = false;

      if (resolvedConnectionId.isNotEmpty) {
        final doc = await _firestore
            .collection('follow_requests')
            .doc(resolvedConnectionId)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['status'] == 'accepted') {
            isConnected = true;
          }
        }
      }

      if (!isConnected) {
        final forwardId = '${teacherId}_$studentId';
        final doc1 = await _firestore
            .collection('follow_requests')
            .doc(forwardId)
            .get();
        if (doc1.exists && doc1.data() != null) {
          final data = doc1.data()!;
          if (data['status'] == 'accepted') {
            isConnected = true;
            resolvedConnectionId = forwardId;
          }
        }
      }

      if (!isConnected) {
        final reverseId = '${studentId}_$teacherId';
        final doc2 = await _firestore
            .collection('follow_requests')
            .doc(reverseId)
            .get();
        if (doc2.exists && doc2.data() != null) {
          final data = doc2.data()!;
          if (data['status'] == 'accepted') {
            isConnected = true;
            resolvedConnectionId = reverseId;
          }
        }
      }

      if (!isConnected) {
        final querySnap = await _firestore
            .collection('follow_requests')
            .where('teacherId', isEqualTo: teacherId)
            .where('studentId', isEqualTo: studentId)
            .where('status', isEqualTo: 'accepted')
            .limit(1)
            .get();

        if (querySnap.docs.isNotEmpty) {
          isConnected = true;
          resolvedConnectionId = querySnap.docs.first.id;
        }
      }

      if (!isConnected) {
        final studentDoc =
            await _firestore.collection('students').doc(studentId).get();
        if (studentDoc.exists) {
          isConnected = true;
          resolvedConnectionId = '${teacherId}_$studentId';
        }
      }

      if (!isConnected) {
        return {
          'isValid': false,
          'status': 'rejected',
          'reason':
              'Only connected or registered students can review this educator.',
        };
      }

      final currentSeasonId = SeasonModel.current().id;

      bool isFlagged = false;
      String? flagReason;

      try {
        final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
        final recentBurstQuery = await _firestore
            .collection('teacher_reviews')
            .where('teacherId', isEqualTo: teacherId)
            .where('createdAt', isGreaterThan: Timestamp.fromDate(oneHourAgo))
            .get();

        if (recentBurstQuery.docs.length >=
            AlgorithmConfig.suspiciousBurstReviewCountInOneHour) {
          isFlagged = true;
          flagReason =
              'High rating velocity detected within 1 hour; queued for manual verification.';
        }
      } catch (_) {}

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
