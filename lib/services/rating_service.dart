import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/algorithm_config.dart';
import '../models/rating_summary_model.dart';
import '../models/review_model.dart';
import 'anti_fraud_service.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AntiFraudService _antiFraudService = AntiFraudService();

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

  /// নিশ্চিত করে যে শিক্ষার্থী সত্যিই ওই শিক্ষকের অ্যাক্সেপ্টেড স্টুডেন্ট কি না
  Future<bool> isStudentAcceptedByTeacher({
    required String teacherId,
    required String studentId,
  }) async {
    if (teacherId.isEmpty || studentId.isEmpty || teacherId == studentId) {
      return false;
    }

    try {
      final reqSnap = await _firestore
          .collection('follow_requests')
          .where('teacherId', isEqualTo: teacherId)
          .where('senderId', isEqualTo: studentId)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (reqSnap.docs.isNotEmpty) return true;

      final backupSnap = await _firestore
          .collection('follow_requests')
          .where('teacherId', isEqualTo: teacherId)
          .where('studentId', isEqualTo: studentId)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (backupSnap.docs.isNotEmpty) return true;

      final connectedSnap = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .collection('connected_students')
          .doc(studentId)
          .get();

      if (connectedSnap.exists) return true;

      return false;
    } catch (_) {
      return false;
    }
  }

  Future> submitReview({
    required String teacherId,
    required String studentId,
    required String studentName,
    required String studentPhotoUrl,
    required String connectionId,
    required String subjectId,
    required double stars,
    required CategoryRating categories,
    required String reviewText,
  }) async {
    try {
      // ১. কঠোর স্টুডেন্ট এলিজিবিলিটি চেক
      final bool isAccepted = await isStudentAcceptedByTeacher(
        teacherId: teacherId,
        studentId: studentId,
      );

      if (!isAccepted) {
        return {
          'success': false,
          'message': 'Only officially accepted students of this teacher can give ratings.',
        };
      }

      final validationResult = await _antiFraudService.validateAndProcessReview(
        teacherId: teacherId,
        studentId: studentId,
        connectionId: connectionId,
        subjectId: subjectId,
        stars: stars,
        reviewText: reviewText,
      );

      if (validationResult['isValid'] != true) {
        return {
          'success': false,
          'message': validationResult['reason'] ?? 'Review validation failed.',
        };
      }

      final status = validationResult['status'] ?? 'verified';
      final isVerified = validationResult['isVerified'] ?? true;
      final flagReason = validationResult['flagReason'];
      final resolvedConnectionId =
          validationResult['connectionId'] ?? connectionId;
      final seasonId = validationResult['seasonId'] ??
          ReviewModel.getCurrentSeasonId(DateTime.now());

      final existingReviewSnap = await _firestore
          .collection('reviews')
          .where('teacherId', isEqualTo: teacherId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      final DocumentReference reviewRef = existingReviewSnap.docs.isNotEmpty
          ? existingReviewSnap.docs.first.reference
          : _firestore.collection('reviews').doc();

      final reviewModel = ReviewModel(
        id: reviewRef.id,
        teacherId: teacherId,
        studentId: studentId,
        studentName: studentName,
        studentPhotoUrl: studentPhotoUrl,
        connectionId: resolvedConnectionId,
        subjectId: subjectId,
        seasonId: seasonId,
        categories: categories,
        overallRating: stars,
        comment: reviewText,
        createdAt: DateTime.now(),
        status: status,
        isVerified: isVerified,
        flagReason: flagReason,
      );

      final batch = _firestore.batch();
      batch.set(reviewRef, reviewModel.toMap(), SetOptions(merge: true));

      final ratingDocRef =
          _firestore.collection('ratings').doc('${teacherId}_$studentId');
      batch.set(
        ratingDocRef,
        {
          'teacherId': teacherId,
          'studentId': studentId,
          'studentName': studentName,
          'studentPhotoUrl': studentPhotoUrl,
          'overallRating': stars,
          'categories': categories.toMap(),
          'comment': reviewText,
          'seasonId': seasonId,
          'status': status,
          'isVerified': isVerified,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final followDocId = resolvedConnectionId.isNotEmpty
          ? resolvedConnectionId
          : '${teacherId}_$studentId';
      final followRef =
          _firestore.collection('follow_requests').doc(followDocId);
      batch.set(
        followRef,
        {
          'lastRatedSeasonId': seasonId,
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (status == 'flagged') {
        await _antiFraudService.logAuditTrail(
          reviewId: reviewRef.id,
          teacherId: teacherId,
          studentId: studentId,
          status: status,
          reason: flagReason ?? 'Flagged by anti-fraud heuristics.',
        );
      }

      if (isVerified) {
        await recalculateTeacherRatings(teacherId);
      }

      return {
        'success': true,
        'status': status,
        'message': status == 'flagged'
            ? 'Review submitted successfully and is pending review verification.'
            : 'Review submitted and verified successfully.',
      };
    } catch (e) {
      debugPrint("Error submitting review: $e");
      return {
        'success': false,
        'message': 'An error occurred while submitting the review: $e',
      };
    }
  }

  Future<void> recalculateTeacherRatings(String teacherId) async {
    try {
      final reviewsQuery = await _firestore
          .collection('reviews')
          .where('teacherId', isEqualTo: teacherId)
          .where('status', isEqualTo: 'verified')
          .get();

      List> rawReviewDocs =
          reviewsQuery.docs.map((d) => d.data()).toList();

      if (rawReviewDocs.isEmpty) {
        final ratingsQuery = await _firestore
            .collection('ratings')
            .where('teacherId', isEqualTo: teacherId)
            .get();

        rawReviewDocs = ratingsQuery.docs.map((d) => d.data()).toList();
      }

      final currentSeasonId = ReviewModel.getCurrentSeasonId(DateTime.now());

      if (rawReviewDocs.isEmpty) {
        final initialSummary = RatingSummaryModel.initial(teacherId);
        await _firestore
            .collection('teacher_rating_summary')
            .doc(teacherId)
            .set(initialSummary.toMap());

        await _firestore.collection('teachers').doc(teacherId).set({
          'averageRating': 0.0,
          'allTimeRating': 0.0,
          'reviewCount': 0,
          'ratingCount': 0,
          'currentSeasonRating': 0.0,
          'currentSeason': currentSeasonId,
          'qualityBadge': 'NONE',
        }, SetOptions(merge: true));
        return;
      }

      double totalStars = 0;
      int totalReviewsCount = rawReviewDocs.length;
      final starDist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      double sumTeaching = 0;
      double sumBehaviour = 0;
      double sumCommunication = 0;
      double sumKnowledge = 0;
      double sumPunctuality = 0;

      double seasonTotalStars = 0;
      int seasonReviewsCount = 0;

      final Map<String, List>> subjectReviewsMap = {};

      for (var data in rawReviewDocs) {
        final double star = (data['overallRating'] ?? data['rating'] as num?)?.toDouble() ?? 5.0;
        totalStars += star;

        final roundedStar = star.round().clamp(1, 5);
        starDist[roundedStar] = (starDist[roundedStar] ?? 0) + 1;

        final cat = data['categories'] as Map<String, dynamic>? ?? {};
        sumTeaching += (cat['teaching'] as num?)?.toDouble() ?? star;
        sumBehaviour += (cat['behaviour'] as num?)?.toDouble() ?? star;
        sumCommunication += (cat['communication'] as num?)?.toDouble() ?? star;
        sumKnowledge += (cat['knowledge'] as num?)?.toDouble() ?? star;
        sumPunctuality += (cat['punctuality'] as num?)?.toDouble() ?? star;

        final season = data['seasonId']?.toString() ?? currentSeasonId;
        if (season == currentSeasonId) {
          seasonTotalStars += star;
          seasonReviewsCount++;
        }

        final subId = (data['subjectId'] ?? 'general').toString();
        subjectReviewsMap.putIfAbsent(subId, () => []).add(data);
      }

      final avgRating =
          double.parse((totalStars / totalReviewsCount).toStringAsFixed(2));
      final seasonAvgRating = seasonReviewsCount > 0
          ? double.parse(
              (seasonTotalStars / seasonReviewsCount).toStringAsFixed(2))
          : 0.0;

      final categoryAverages = {
        'teaching':
            double.parse((sumTeaching / totalReviewsCount).toStringAsFixed(1)),
        'behaviour':
            double.parse((sumBehaviour / totalReviewsCount).toStringAsFixed(1)),
        'communication': double.parse(
            (sumCommunication / totalReviewsCount).toStringAsFixed(1)),
        'knowledge':
            double.parse((sumKnowledge / totalReviewsCount).toStringAsFixed(1)),
        'punctuality': double.parse(
            (sumPunctuality / totalReviewsCount).toStringAsFixed(1)),
      };

      final Map<String, SubjectRatingSummary> subjectSummaries = {};
      subjectReviewsMap.forEach((subId, subReviews) {
        double subStars = 0;
        for (var r in subReviews) {
          subStars += (r['overallRating'] ?? r['rating'] as num?)?.toDouble() ?? 5.0;
        }
        final subAvg =
            double.parse((subStars / subReviews.length).toStringAsFixed(2));

        final vCount = subReviews.length;
        final compScore = ((vCount * subAvg) +
                (AlgorithmConfig.bayesianPriorStrengthM *
                    AlgorithmConfig.defaultSubjectGroupAverageC)) /
            (vCount + AlgorithmConfig.bayesianPriorStrengthM);

        String badge = 'NONE';
        if (vCount >= AlgorithmConfig.kBadgeMinVerifiedReviews &&
            subAvg >= AlgorithmConfig.kBadgeMinPublicRating) {
          badge = 'K';
        } else if (vCount >= AlgorithmConfig.bBadgeMinVerifiedReviews &&
            subAvg >= AlgorithmConfig.bBadgeMinPublicRating) {
          badge = 'B';
        } else if (vCount >= AlgorithmConfig.mBadgeMinVerifiedReviews &&
            subAvg >= AlgorithmConfig.mBadgeMinPublicRating) {
          badge = 'M';
        }

        subjectSummaries[subId] = SubjectRatingSummary(
          subjectId: subId,
          subjectName: subId,
          averageRating: subAvg,
          verifiedReviews: vCount,
          competitionScore: double.parse(compScore.toStringAsFixed(2)),
          awardedBadge: badge,
          eligibilityStatus:
              vCount >= AlgorithmConfig.tierLimitedCompMinReviews
                  ? 'Eligible'
                  : AlgorithmConfig.insufficientEvidenceText,
          isSubjectVerified: true,
        );
      });

      final competitionScore = ((totalReviewsCount * avgRating) +
              (AlgorithmConfig.bayesianPriorStrengthM *
                  AlgorithmConfig.defaultSubjectGroupAverageC)) /
          (totalReviewsCount + AlgorithmConfig.bayesianPriorStrengthM);

      String overallBadge = 'NONE';
      if (totalReviewsCount >= AlgorithmConfig.kBadgeMinVerifiedReviews &&
          avgRating >= AlgorithmConfig.kBadgeMinPublicRating) {
        overallBadge = 'K';
      } else if (totalReviewsCount >= AlgorithmConfig.bBadgeMinVerifiedReviews &&
          avgRating >= AlgorithmConfig.bBadgeMinPublicRating) {
        overallBadge = 'B';
      } else if (totalReviewsCount >= AlgorithmConfig.mBadgeMinVerifiedReviews &&
          avgRating >= AlgorithmConfig.mBadgeMinPublicRating) {
        overallBadge = 'M';
      }

      final summaryModel = RatingSummaryModel(
        teacherId: teacherId,
        averageRating: avgRating,
        totalReviews: totalReviewsCount,
        totalRatings: totalReviewsCount,
        verifiedReviewsCount: totalReviewsCount,
        competitionScore: double.parse(competitionScore.toStringAsFixed(2)),
        currentSeasonId: currentSeasonId,
        currentSeasonAverageRating: seasonAvgRating,
        currentSeasonVerifiedReviews: seasonReviewsCount,
        currentSeasonCompetitionScore:
            seasonReviewsCount > 0 ? seasonAvgRating : 0.0,
        currentBadge: overallBadge,
        eligibilityStatus:
            totalReviewsCount >= AlgorithmConfig.tierLimitedCompMinReviews
                ? 'Eligible'
                : AlgorithmConfig.insufficientEvidenceText,
        starDistribution: starDist,
        categoryAverages: categoryAverages,
        subjectSummaries: subjectSummaries,
        lastUpdated: DateTime.now(),
      );

      await _firestore
          .collection('teacher_rating_summary')
          .doc(teacherId)
          .set(summaryModel.toMap());

      await _firestore.collection('teachers').doc(teacherId).set({
        'averageRating': avgRating,
        'allTimeRating': avgRating,
        'reviewCount': totalReviewsCount,
        'ratingCount': totalReviewsCount,
        'currentSeasonRating': seasonAvgRating,
        'currentSeason': currentSeasonId,
        'qualityBadge': overallBadge,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error recalculating teacher ratings: $e");
    }
  }

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
