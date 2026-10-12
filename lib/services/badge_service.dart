import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/badge_model.dart';
import '../models/rating_summary_model.dart';

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<BadgeModel>> streamTeacherBadges(String teacherId) {
    return _firestore
        .collection('teacher_badges')
        .where('teacherId', isEqualTo: teacherId)
        .where('isCurrentlyActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BadgeModel.fromFirestore(doc)).toList());
  }

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

  Future<BadgeType> evaluateAndAssignBadges({
    required String teacherId,
    required bool isAdminApproved,
    required bool documentsApproved,
    required RatingSummaryModel ratingSummary,
    required int platformYearsActive,
  }) async {
    try {
      BadgeType assignedBadge = BadgeType.verified;

      if (ratingSummary.averageRating == 5.0 && ratingSummary.totalReviews >= 10) {
        assignedBadge = BadgeType.king;
      } else if (ratingSummary.averageRating >= 4.2) {
        assignedBadge = BadgeType.best;
      } else if (ratingSummary.averageRating >= 3.8) {
        assignedBadge = BadgeType.master;
      } else if (platformYearsActive >= 3) {
        assignedBadge = BadgeType.golden;
      } else if (isAdminApproved && documentsApproved) {
        assignedBadge = BadgeType.verified;
      }

      final badgeRef = _firestore
          .collection('teacher_badges')
          .doc('${teacherId}_${assignedBadge.name}');

      final existingBadge = await badgeRef.get();

      if (!existingBadge.exists) {
        final newBadge = BadgeModel(
          id: badgeRef.id,
          teacherId: teacherId,
          type: assignedBadge,
          unlockedAt: DateTime.now(),
          isCurrentlyActive: true,
          assignedReason: _getReasonForBadge(assignedBadge),
        );

        await badgeRef.set(newBadge.toMap());
      }

      await _firestore.collection('teachers').doc(teacherId).update({
        'isVerified': isAdminApproved && documentsApproved,
        'hasSpecialBadge': assignedBadge != BadgeType.verified,
        'highestBadgeType': assignedBadge.toMapValue(),
        'badgePriorityScore': assignedBadge.priority,
      });

      return assignedBadge;
    } catch (e) {
      debugPrint("Error evaluating teacher badges: $e");
      return BadgeType.verified;
    }
  }

  String _getReasonForBadge(BadgeType badge) {
    switch (badge) {
      case BadgeType.king:
        return 'Achieved a perfect 5.0-star rating under platform criteria.';
      case BadgeType.best:
        return 'Maintained a minimum 4.2-star rating.';
      case BadgeType.master:
        return 'Maintained a minimum 3.8-star rating over the defined period.';
      case BadgeType.golden:
        return 'Successfully completed 3 years on the platform.';
      case BadgeType.verified:
        return 'Verified identity and credentials approved by system.';
    }
  }
}
