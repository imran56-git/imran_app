import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/review_model.dart';
import '../models/rating_summary_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if a student is eligible to review a teacher.
  /// Conditions: Must have chat history, completed tuition, or completed live class.
  /// Self-review is strictly blocked.
  Future<bool> canStudentReviewTeacher({
    required String studentId,
    required String teacherId,
  }) async {
    try {
      if (studentId == teacherId) {
        debugPrint("Security Block: Teacher cannot review themselves.");
        return false;
      }

      // Check if already reviewed
      final existingReview = await _firestore
          .collection('teacher_reviews')
          .where('teacherId', isEqualTo: teacherId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (existingReview.docs.isNotEmpty) {
        // Can edit within 30 days, but cannot create a secondary review
        return true; 
      }

      // 1. Check Chat System interaction
      final chatQuery = await _firestore
          .collection('chats')
          .where('participants', arrayContains: studentId)
          .get();

      bool hasChat = chatQuery.docs.any((doc) {
        final data = doc.data();
        final List participants = data['participants'] ?? [];
        return participants.contains(teacherId);
      });

      if (hasChat) return true;

      // 2. Check Completed Tuition record
      final tuitionQuery = await _firestore
          .collection('tuitions')
          .where('studentId', isEqualTo: studentId)
          .where('teacherId', isEqualTo: teacherId)
          .where('status', isEqualTo: 'completed')
          .limit(1)
          .get();

      if (tuitionQuery.docs.isNotEmpty) return true;

      // 3. Check Live Class record
      final liveClassQuery = await _firestore
          .collection('live_classes')
          .where('studentId', isEqualTo: studentId)
          .where('teacherId', isEqualTo: teacherId)
          .where('status', isEqualTo: 'completed')
          .limit(1)
          .get();

      if (liveClassQuery.docs.isNotEmpty) return true;

      return false;
    } catch (e) {
      debugPrint("Error checking review eligibility: $e");
      return false;
    }
  }

  /// Submit a new review or edit an existing one (within 30 days limit).
  Future<bool> submitOrUpdateReview({
    required ReviewModel review,
  }) async {
    try {
      if (review.studentId == review.teacherId) {
        throw Exception("Self-review is strictly forbidden.");
      }

      final reviewRef = _firestore.collection('teacher_reviews').doc(
            review.id.isEmpty ? null : review.id,
          );

      final docSnapshot = await reviewRef.get();

      if (docSnapshot.exists) {
        // Edit flow
        final existingReview = ReviewModel.fromFirestore(docSnapshot);
        if (!existingReview.canBeEdited) {
          throw Exception("Review editing window (30 days) has expired.");
        }

        final updatedReview = review.copyWith(
          id: reviewRef.id,
          updatedAt: DateTime.now(),
          isEdited: true,
        );

        await reviewRef.update(updatedReview.toMap());
      } else {
        // Create flow
        final newReview = review.copyWith(
          id: reviewRef.id,
          createdAt: DateTime.now(),
        );

        await reviewRef.set(newReview.toMap());

        // Update student's ratedTeachers list
        await _firestore.collection('students').doc(review.studentId).update({
          'ratedTeachers': FieldValue.arrayUnion([review.teacherId]),
        });
      }

      // Re-calculate rating summary for the teacher atomically
      await _recalculateTeacherSummary(review.teacherId);

      return true;
    } catch (e) {
      debugPrint("Error submitting or updating review: $e");
      return false;
    }
  }

  /// Fetch paginated reviews for a specific teacher
  Future<List<ReviewModel>> getTeacherReviews({
    required String teacherId,
    DocumentSnapshot? startAfter,
    int limit = 10,
  }) async {
    try {
      Query query = _firestore
          .collection('teacher_reviews')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint("Error fetching teacher reviews: $e");
      return [];
    }
  }

  /// Toggle Helpful counter for a review
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

  /// Report inappropriate review
  Future<void> reportReview({
    required String reviewId,
    required String studentId,
  }) async {
    try {
      final docRef = _firestore.collection('teacher_reviews').doc(reviewId);
      await docRef.update({
        'reportedByStudentIds': FieldValue.arrayUnion([studentId]),
      });
    } catch (e) {
      debugPrint("Error reporting review: $e");
    }
  }

  /// Teacher reply to a review
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

  /// Private helper method to recalculate overall rating summary and update Firestore
  Future<void> _recalculateTeacherSummary(String teacherId) async {
    try {
      final reviewsQuery = await _firestore
          .collection('teacher_reviews')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      if (reviewsQuery.docs.isEmpty) return;

      final reviews = reviewsQuery.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();

      int totalReviews = reviews.length;
      double totalOverallSum = 0.0;

      double teachingSum = 0.0;
      double behaviourSum = 0.0;
      double communicationSum = 0.0;
      double knowledgeSum = 0.0;
      double punctualitySum = 0.0;

      Map<int, int> starDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

      for (var r in reviews) {
        totalOverallSum += r.overallRating;

        // Categorical sums
        teachingSum += r.categories.teaching;
        behaviourSum += r.categories.behaviour;
        communicationSum += r.categories.communication;
        knowledgeSum += r.categories.knowledge;
        punctualitySum += r.categories.punctuality;

        // Star distribution based on rounded overall rating
        int roundedStar = r.overallRating.round().clamp(1, 5);
        starDistribution[roundedStar] = (starDistribution[roundedStar] ?? 0) + 1;
      }

      double avgRating = double.parse(
        (totalOverallSum / totalReviews).toStringAsFixed(1),
      );

      final summary = RatingSummaryModel(
        teacherId: teacherId,
        averageRating: avgRating,
        totalReviews: totalReviews,
        totalRatings: totalReviews,
        starDistribution: starDistribution,
        categoryAverages: {
          'teaching': double.parse((teachingSum / totalReviews).toStringAsFixed(1)),
          'behaviour': double.parse((behaviourSum / totalReviews).toStringAsFixed(1)),
          'communication': double.parse((communicationSum / totalReviews).toStringAsFixed(1)),
          'knowledge': double.parse((knowledgeSum / totalReviews).toStringAsFixed(1)),
          'punctuality': double.parse((punctualitySum / totalReviews).toStringAsFixed(1)),
        },
        lastUpdated: DateTime.now(),
      );

      // Save summary in `teacher_rating_summary` collection
      await _firestore
          .collection('teacher_rating_summary')
          .doc(teacherId)
          .set(summary.toMap(), SetOptions(merge: true));

      // Also update the core `teachers` document directly for fast search indexing
      await _firestore.collection('teachers').doc(teacherId).update({
        'averageRating': avgRating,
        'ratingCount': totalReviews,
        'reviewCount': totalReviews,
        'allTimeRating': avgRating,
      });
    } catch (e) {
      debugPrint("Error recalculating teacher summary: $e");
    }
  }
}
