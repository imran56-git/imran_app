import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/algorithm_config.dart';
import '../models/rating_summary_model.dart';
import '../models/season_model.dart';
import 'competition_engine_service.dart';

class SeasonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CompetitionEngineService _competitionEngine =
      CompetitionEngineService();

  Future<SeasonModel> getCurrentActiveSeason() async {
    try {
      final currentDynamicSeason = SeasonModel.current();
      final seasonRef =
          _firestore.collection('seasons').doc(currentDynamicSeason.id);

      final doc = await seasonRef.get();

      if (!doc.exists) {
        await seasonRef.set(currentDynamicSeason.toMap());
        await _handleSeasonTransition(currentDynamicSeason);
      }

      return SeasonModel.fromFirestore(await seasonRef.get());
    } catch (e) {
      debugPrint("Error fetching current active season: $e");
      return SeasonModel.current();
    }
  }

  Stream<SeasonModel> streamCurrentSeason() {
    final currentDynamic = SeasonModel.current();
    return _firestore
        .collection('seasons')
        .doc(currentDynamic.id)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return SeasonModel.fromFirestore(doc);
      }
      return currentDynamic;
    });
  }

  Future<List<Map<String, dynamic>>> getSeasonLeaderboard({
    required String seasonId,
    String? subjectId,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('teacher_season_ranking')
          .where('seasonId', isEqualTo: seasonId);

      if (subjectId != null && subjectId.isNotEmpty) {
        query = query.where('subjectId', isEqualTo: subjectId);
      }

      final querySnapshot = await query
          .orderBy('competitionScore', descending: true)
          .orderBy('seasonalRating', descending: true)
          .orderBy('reviewCount', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("Error fetching season leaderboard: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMostImprovedLeaderboard({
    required String seasonId,
    int limit = 20,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('teacher_season_ranking')
          .where('seasonId', isEqualTo: seasonId)
          .where('isMostImproved', isEqualTo: true)
          .orderBy('improvementDelta', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("Error fetching most improved leaderboard: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLifetimeLeaderboard({
    int limit = 50,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('teacher_lifetime_ranking')
          .orderBy('badgePriorityScore', descending: true)
          .orderBy('competitionScore', descending: true)
          .orderBy('allTimeRating', descending: true)
          .orderBy('reviewCount', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("Error fetching lifetime leaderboard: $e");
      return [];
    }
  }

  Future<void> _handleSeasonTransition(SeasonModel newSeason) async {
    try {
      final oldActiveSeasons = await _firestore
          .collection('seasons')
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      final List<SeasonModel> closingSeasons = [];

      for (var doc in oldActiveSeasons.docs) {
        if (doc.id != newSeason.id) {
          closingSeasons.add(SeasonModel.fromFirestore(doc));
          batch.update(doc.reference, {
            'isActive': false,
            'status': 'finalized',
            'isFinalized': true,
            'finalizedAt': Timestamp.now(),
          });
        }
      }

      await batch.commit();

      final teachers = await _firestore.collection('teachers').get();
      for (var teacherDoc in teachers.docs) {
        final teacherId = teacherDoc.id;
        final data = teacherDoc.data();

        final summaryDoc = await _firestore
            .collection('teacher_rating_summary')
            .doc(teacherId)
            .get();

        RatingSummaryModel summary = summaryDoc.exists
            ? RatingSummaryModel.fromFirestore(summaryDoc)
            : RatingSummaryModel.initial(teacherId);

        final List<SeasonHistoryRecord> updatedHistory =
            List<SeasonHistoryRecord>.from(summary.seasonHistory);

        for (final closedSeason in closingSeasons) {
          final alreadyRecorded =
              updatedHistory.any((h) => h.seasonId == closedSeason.id);
          if (!alreadyRecorded && summary.currentSeasonVerifiedReviews > 0) {
            final subBadges = <String, String>{};
            summary.subjectSummaries.forEach((key, val) {
              subBadges[key] = val.awardedBadge;
            });

            updatedHistory.add(
              SeasonHistoryRecord(
                seasonId: closedSeason.id,
                seasonName: closedSeason.name.displayName,
                averageRating: summary.currentSeasonAverageRating,
                verifiedReviews: summary.currentSeasonVerifiedReviews,
                competitionScore: summary.currentSeasonCompetitionScore,
                awardedBadge: summary.currentBadge,
                subjectBadges: subBadges,
                ruleVersion: closedSeason.ruleVersion,
                finalizedAt: DateTime.now(),
              ),
            );
          }
        }

        final resetSummary = summary.copyWith(
          currentSeasonId: newSeason.id,
          currentSeasonAverageRating: 0.0,
          currentSeasonVerifiedReviews: 0,
          currentSeasonCompetitionScore: 0.0,
          currentBadge: 'NONE',
          eligibilityStatus: AlgorithmConfig.insufficientEvidenceText,
          seasonHistory: updatedHistory,
          lastUpdated: DateTime.now(),
        );

        await _firestore
            .collection('teacher_rating_summary')
            .doc(teacherId)
            .set(resetSummary.toMap(), SetOptions(merge: true));

        await _firestore.collection('teachers').doc(teacherId).set({
          'currentSeason': newSeason.name.displayName,
          'currentSeasonId': newSeason.id,
          'lastSeasonRating': summary.currentSeasonAverageRating,
          'seasonalRating': 0.0,
          'seasonalReviewCount': 0,
        }, SetOptions(merge: true));

        await _firestore
            .collection('teacher_season_ranking')
            .doc('${teacherId}_${newSeason.id}')
            .set({
          'teacherId': teacherId,
          'teacherName': data['name'] ?? '',
          'seasonId': newSeason.id,
          'seasonName': newSeason.name.displayName,
          'seasonalRating': 0.0,
          'competitionScore': 0.0,
          'reviewCount': 0,
          'highestBadgeType': 'NONE',
          'eligibilityStatus': AlgorithmConfig.insufficientEvidenceText,
          'isMostImproved': false,
          'improvementDelta': 0.0,
          'ruleVersion': AlgorithmConfig.currentRuleVersion,
          'lastUpdated': Timestamp.now(),
        }, SetOptions(merge: true));

        final priorityScore =
            _competitionEngine.getBadgePriorityScore(summary.currentBadge);

        await _firestore
            .collection('teacher_lifetime_ranking')
            .doc(teacherId)
            .set({
          'teacherId': teacherId,
          'teacherName': data['name'] ?? '',
          'allTimeRating': summary.averageRating,
          'competitionScore': summary.competitionScore,
          'reviewCount': summary.verifiedReviewsCount,
          'badgePriorityScore': priorityScore,
          'isVerifiedBadge': summary.isVerifiedBadge,
          'isGoldenBadge': summary.isGoldenBadge,
          'lastUpdated': Timestamp.now(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error handling season transition: $e");
    }
  }
}
