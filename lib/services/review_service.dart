import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/algorithm_config.dart';
import '../models/review_model.dart';
import '../models/rating_summary_model.dart';
import '../models/season_model.dart';
import 'anti_fraud_service.dart';
import 'competition_engine_service.dart';
import 'follow_service.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FollowService _followService = FollowService();
  final AntiFraudService _antiFraudService = AntiFraudService();
  final CompetitionEngineService _competitionEngine =
      CompetitionEngineService();

  Future<bool> canStudentReviewTeacher({
    required String studentId,
    required String teacherId,
  }) async {
    try {
      if (studentId.isEmpty || teacherId.isEmpty || studentId == teacherId) {
        return false;
      }

      final connection =
          await _followService.getFollowConnection(teacherId, studentId);
      if (connection == null || !connection.isEligibleToRate) {
        return false;
      }

      final currentSeasonId = SeasonModel.current().id;

      final existingSeasonReview = await _firestore
          .collection('teacher_reviews')
          .where('teacherId', isEqualTo: teacherId)
          .where('studentId', isEqualTo: studentId)
          .where('seasonId', isEqualTo: currentSeasonId)
          .limit(1)
          .get();

      if (existingSeasonReview.docs.isNotEmpty) {
        final existing =
            ReviewModel.fromFirestore(existingSeasonReview.docs.first);
        return existing.canBeEdited;
      }

      return true;
    } catch (e) {
      debugPrint("Error checking review eligibility: $e");
      return false;
    }
  }

  Future<ReviewModel?> getStudentReviewForCurrentSeason({
    required String studentId,
    required String teacherId,
  }) async {
    try {
      final currentSeasonId = SeasonModel.current().id;
      final query = await _firestore
          .collection('teacher_reviews')
          .where('teacherId', isEqualTo: teacherId)
          .where('studentId', isEqualTo: studentId)
          .where('seasonId', isEqualTo: currentSeasonId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return ReviewModel.fromFirestore(query.docs.first);
    } catch (e) {
      debugPrint("Error fetching student season review: $e");
      return null;
    }
  }

  Future<bool> submitOrUpdateReview({
    required ReviewModel review,
  }) async {
    try {
      if (review.studentId == review.teacherId) {
        throw Exception("Self-review is strictly forbidden.");
      }

      final currentSeason = SeasonModel.current();
      final activeSeasonId =
          review.seasonId.isNotEmpty ? review.seasonId : currentSeason.id;

      final validationResult = await _antiFraudService.validateAndProcessReview(
        teacherId: review.teacherId,
        studentId: review.studentId,
        connectionId: review.connectionId,
        subjectId: review.subjectId,
        stars: review.overallRating,
        reviewText: review.comment,
      );

      if (validationResult['isValid'] != true) {
        throw Exception(
          validationResult['reason'] ?? 'Review validation failed.',
        );
      }

      final validatedStatus = validationResult['status'] as String? ?? 'verified';
      final validatedIsVerified =
          validationResult['isVerified'] as bool? ?? true;
      final flagReason = validationResult['flagReason'] as String?;
      final resolvedConnectionId =
          validationResult['connectionId'] as String? ??
              '${review.teacherId}_${review.studentId}';

      final existingSeasonQuery = await _firestore
          .collection('teacher_reviews')
          .where('teacherId', isEqualTo: review.teacherId)
          .where('studentId', isEqualTo: review.studentId)
          .where('seasonId', isEqualTo: activeSeasonId)
          .limit(1)
          .get();

      DocumentReference<Map<String, dynamic>> reviewRef;
      DocumentSnapshot<Map<String, dynamic>>? existingDocSnap;

      if (existingSeasonQuery.docs.isNotEmpty) {
        existingDocSnap = existingSeasonQuery.docs.first;
        reviewRef = existingDocSnap.reference;
      } else if (review.id.isNotEmpty) {
        reviewRef = _firestore.collection('teacher_reviews').doc(review.id);
        final snap = await reviewRef.get();
        if (snap.exists) {
          existingDocSnap = snap;
        }
      } else {
        final deterministicId =
            '${review.teacherId}_${review.studentId}_$activeSeasonId';
        reviewRef =
            _firestore.collection('teacher_reviews').doc(deterministicId);
        final snap = await reviewRef.get();
        if (snap.exists) {
          existingDocSnap = snap;
        }
      }

      if (existingDocSnap != null && existingDocSnap.exists) {
        final existingReview = ReviewModel.fromFirestore(existingDocSnap);
        if (!existingReview.canBeEdited) {
          throw Exception("Review editing window for this season has expired.");
        }

        final updatedReview = review.copyWith(
          id: reviewRef.id,
          connectionId: resolvedConnectionId,
          seasonId: existingReview.seasonId.isNotEmpty
              ? existingReview.seasonId
              : activeSeasonId,
          createdAt: existingReview.createdAt,
          updatedAt: DateTime.now(),
          isEdited: true,
          updateCount: existingReview.updateCount + 1,
          status: validatedStatus,
          isVerified: validatedIsVerified,
          flagReason: flagReason,
          ruleVersion: AlgorithmConfig.currentRuleVersion,
        );

        await reviewRef.set(updatedReview.toMap(), SetOptions(merge: true));
      } else {
        final newReview = review.copyWith(
          id: reviewRef.id,
          connectionId: resolvedConnectionId,
          seasonId: activeSeasonId,
          createdAt: DateTime.now(),
          status: validatedStatus,
          isVerified: validatedIsVerified,
          flagReason: flagReason,
          updateCount: 0,
          ruleVersion: AlgorithmConfig.currentRuleVersion,
        );

        await reviewRef.set(newReview.toMap());

        await _firestore.collection('students').doc(review.studentId).set({
          'ratedTeachers': FieldValue.arrayUnion([review.teacherId]),
        }, SetOptions(merge: true));
      }

      await _firestore
          .collection('follow_requests')
          .doc(resolvedConnectionId)
          .set({
        'lastRatedSeasonId': activeSeasonId,
      }, SetOptions(merge: true));

      if (validatedStatus == 'flagged') {
        await _antiFraudService.logAuditTrail(
          reviewId: reviewRef.id,
          teacherId: review.teacherId,
          studentId: review.studentId,
          status: validatedStatus,
          reason: flagReason ?? 'Flagged for review verification.',
        );
      }

      await recalculateTeacherSummary(review.teacherId);

      return true;
    } catch (e) {
      debugPrint("Error submitting or updating review: $e");
      return false;
    }
  }

  Future<List<ReviewModel>> getTeacherReviews({
    required String teacherId,
    String? seasonId,
    String? subjectId,
    bool onlyVerified = true,
    DocumentSnapshot? startAfter,
    int limit = 10,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('teacher_reviews')
          .where('teacherId', isEqualTo: teacherId);

      if (seasonId != null && seasonId.isNotEmpty) {
        query = query.where('seasonId', isEqualTo: seasonId);
      }

      if (subjectId != null && subjectId.isNotEmpty) {
        query = query.where('subjectId', isEqualTo: subjectId);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get();
      final allFetched = querySnapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();

      if (onlyVerified) {
        return allFetched.where((r) => r.isEligibleForCalculation).toList();
      }
      return allFetched;
    } catch (e) {
      debugPrint("Error fetching teacher reviews: $e");
      return [];
    }
  }

  Future<void> toggleHelpful({
    required String reviewId,
    required String studentId,
  }) async {
    try {
      final docRef = _firestore.collection('teacher_reviews').doc(reviewId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final review = ReviewModel.fromFirestore(doc);
      final hasLiked = review.helpfulStudentIds.contains(studentId);

      if (hasLiked) {
        await docRef.update({
          'helpfulStudentIds': FieldValue.arrayRemove([studentId]),
        });
      } else {
        await docRef.update({
          'helpfulStudentIds': FieldValue.arrayUnion([studentId]),
        });
      }
    } catch (e) {
      debugPrint("Error toggling helpful status: $e");
    }
  }

  Future<void> reportReview({
    required String reviewId,
    required String studentId,
    String? reason,
  }) async {
    try {
      final docRef = _firestore.collection('teacher_reviews').doc(reviewId);
      await docRef.update({
        'reportedByStudentIds': FieldValue.arrayUnion([studentId]),
      });

      final doc = await docRef.get();
      if (doc.exists) {
        final review = ReviewModel.fromFirestore(doc);
        if (review.reportedByStudentIds.length >= 3 &&
            review.status == 'verified') {
          await _antiFraudService.logAuditTrail(
            reviewId: reviewId,
            teacherId: review.teacherId,
            studentId: review.studentId,
            status: 'reported_for_review',
            reason: reason ?? 'Multiple user reports received.',
          );
        }
      }
    } catch (e) {
      debugPrint("Error reporting review: $e");
    }
  }

  Future<bool> replyToReview({
    required String reviewId,
    required String teacherReply,
  }) async {
    try {
      final docRef = _firestore.collection('teacher_reviews').doc(reviewId);
      await docRef.update({
        'teacherReply': teacherReply,
        'teacherReplyAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      debugPrint("Error replying to review: $e");
      return false;
    }
  }

  Future<void> recalculateTeacherSummary(String teacherId) async {
    await _recalculateTeacherSummary(teacherId);
  }

  Future<void> _recalculateTeacherSummary(String teacherId) async {
    try {
      final reviewsQuery = await _firestore
          .collection('teacher_reviews')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      final teacherDoc =
          await _firestore.collection('teachers').doc(teacherId).get();
      final teacherData = teacherDoc.data() ?? {};
      final bool isIdentityVerified =
          teacherData['isVerified'] == true ||
          teacherData['isIdentityVerified'] == true;
      final DateTime? teacherCreatedAt =
          (teacherData['createdAt'] as Timestamp?)?.toDate();

      final existingSummaryDoc = await _firestore
          .collection('teacher_rating_summary')
          .doc(teacherId)
          .get();
      final List<SeasonHistoryRecord> existingHistory =
          existingSummaryDoc.exists
              ? RatingSummaryModel.fromFirestore(existingSummaryDoc)
                  .seasonHistory
              : const [];

      final allReviews = reviewsQuery.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .where((r) => r.isEligibleForCalculation)
          .toList();

      final summary = await _competitionEngine.computeFullTeacherEvaluation(
        teacherId: teacherId,
        allVerifiedReviews: allReviews,
        existingHistory: existingHistory,
        isIdentityVerified: isIdentityVerified,
        teacherCreatedAt: teacherCreatedAt,
      );

      final currentSeason = SeasonModel.current();
      final priorityScore =
          _competitionEngine.getBadgePriorityScore(summary.currentBadge);

      await _firestore.collection('teachers').doc(teacherId).set({
        'averageRating': summary.averageRating,
        'publicRatingDisplay': summary.publicRatingDisplay,
        'competitionScore': summary.competitionScore,
        'ratingCount': summary.verifiedReviewsCount,
        'reviewCount': summary.verifiedReviewsCount,
        'verifiedReviewsCount': summary.verifiedReviewsCount,
        'allTimeRating': summary.averageRating,
        'seasonalRating': summary.currentSeasonAverageRating,
        'seasonalReviewCount': summary.currentSeasonVerifiedReviews,
        'seasonalCompetitionScore': summary.currentSeasonCompetitionScore,
        'currentSeasonId': currentSeason.id,
        'currentSeason': currentSeason.name.displayName,
        'currentBadge': summary.currentBadge,
        'highestBadgeType': summary.currentBadge != 'NONE'
            ? summary.currentBadge
            : (summary.isVerifiedBadge ? 'verified' : 'none'),
        'isVerifiedBadge': summary.isVerifiedBadge,
        'isGoldenBadge': summary.isGoldenBadge,
        'isMostImproved': summary.isMostImproved,
        'eligibilityStatus': summary.eligibilityStatus,
      }, SetOptions(merge: true));

      await _firestore
          .collection('teacher_season_ranking')
          .doc('${teacherId}_${currentSeason.id}')
          .set({
        'teacherId': teacherId,
        'teacherName': teacherData['name'] ?? '',
        'seasonId': currentSeason.id,
        'seasonName': currentSeason.name.displayName,
        'seasonalRating': summary.currentSeasonAverageRating,
        'competitionScore': summary.currentSeasonCompetitionScore,
        'reviewCount': summary.currentSeasonVerifiedReviews,
        'highestBadgeType': summary.currentBadge,
        'eligibilityStatus': summary.eligibilityStatus,
        'isMostImproved': summary.isMostImproved,
        'ruleVersion': AlgorithmConfig.currentRuleVersion,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));

      await _firestore
          .collection('teacher_lifetime_ranking')
          .doc(teacherId)
          .set({
        'teacherId': teacherId,
        'teacherName': teacherData['name'] ?? '',
        'allTimeRating': summary.averageRating,
        'competitionScore': summary.competitionScore,
        'reviewCount': summary.verifiedReviewsCount,
        'badgePriorityScore': priorityScore,
        'isVerifiedBadge': summary.isVerifiedBadge,
        'isGoldenBadge': summary.isGoldenBadge,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error recalculating teacher summary: $e");
    }
  }
}
