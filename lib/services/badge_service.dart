import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/badge_model.dart';
import '../models/rating_summary_model.dart';

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of badges assigned to a specific teacher
  Stream<List<BadgeModel>> streamTeacherBadges(String teacherId) {
    return _firestore
        .collection('teacher_badges')
        .where('teacherId', isEqualTo: teacherId)
        .where('isCurrentlyActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BadgeModel.fromFirestore(doc)).toList());
  }

  /// Get active badges for a teacher once
  Future<List<BadgeModel>> getTeacherBadges(String teacherId) async {
    try {
      final query = await _firestore
          .collection('teacher_badges')
          .where('teacherId', isEqualTo: teacherId)
          .where('isCurrentlyActive', isEqualTo: true)
          .get();

      return query.docs.map((doc) => BadgeModel.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint("Error fetching teacher badges: $e");
      return [];
    }
  }

  /// Automatically evaluate and assign badges based on system rules
  Future<BadgeType> evaluateAndAssignBadges({
    required String teacherId,
    required bool isAdminApproved,
    required bool documentsApproved,
    required RatingSummaryModel ratingSummary,
  }) async {
    try {
      BadgeType highestBadge = BadgeType.verified;

      // 1. Check Master Badge Condition: Rating >= 4.9 & Reviews >= 500
      if (ratingSummary.averageRating >= 4.9 &&
          ratingSummary.totalReviews >= 500) {
        highestBadge = BadgeType.master;
      }
      // 2. Check Golden Badge Condition: Rating >= 4.8 & Reviews >= 100
      else if (ratingSummary.averageRating >= 4.8 &&
          ratingSummary.totalReviews >= 100) {
        highestBadge = BadgeType.golden;
      }
      // 3. Default Verified Badge Condition: Documents Approved & Admin Approved
      else if (isAdminApproved && documentsApproved) {
        highestBadge = BadgeType.verified;
      }

      final badgeRef = _firestore
          .collection('teacher_badges')
          .doc('${teacherId}_${highestBadge.name}');

      final existingBadge = await badgeRef.get();

      if (!existingBadge.exists) {
        final newBadge = BadgeModel(
          id: badgeRef.id,
          teacherId: teacherId,
          type: highestBadge,
          unlockedAt: DateTime.now(),
          isCurrentlyActive: true,
          assignedReason: _getReasonForBadge(highestBadge),
        );

        await badgeRef.set(newBadge.toMap());
      }

      // Sync highest badge priority status back to teacher core profile
      await _firestore.collection('teachers').doc(teacherId).update({
        'isVerified': isAdminApproved && documentsApproved,
        'hasSpecialBadge': highestBadge != BadgeType.verified,
        'highestBadgeType': highestBadge.toMapValue(),
        'badgePriorityScore': highestBadge.priority,
      });

      return highestBadge;
    } catch (e) {
      debugPrint("Error evaluating teacher badges: $e");
      return BadgeType.verified;
    }
  }

  /// Helper to generate human readable assignment reason
  String _getReasonForBadge(BadgeType badge) {
    switch (badge) {
      case BadgeType.master:
        return 'Achieved Rating >= 4.9 and over 500 verified student reviews.';
      case BadgeType.golden:
        return 'Achieved Rating >= 4.8 and over 100 verified student reviews.';
      case BadgeType.verified:
        return 'Verified identity and credentials approved by administration.';
    }
  }
}
