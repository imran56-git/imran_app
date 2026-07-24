import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/season_model.dart';

class SeasonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get or create the current active season
  Future<SeasonModel> getCurrentActiveSeason() async {
    try {
      final currentDynamicSeason = SeasonModel.current();
      final seasonRef = _firestore
          .collection('seasons')
          .doc(currentDynamicSeason.id);

      final doc = await seasonRef.get();

      if (!doc.exists) {
        // Automatically register new season in Firestore
        await seasonRef.set(currentDynamicSeason.toMap());
        
        // Trigger seasonal transition reset logic
        await _handleSeasonTransition(currentDynamicSeason);
      }

      return currentDynamicSeason;
    } catch (e) {
      debugPrint("Error fetching current active season: $e");
      return SeasonModel.current();
    }
  }

  /// Stream of active season
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

  /// Get seasonal ranking leaderboard for teachers
  Future<List<Map<String, dynamic>>> getSeasonLeaderboard({
    required String seasonId,
    int limit = 50,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('teacher_season_ranking')
          .where('seasonId', isEqualTo: seasonId)
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

  /// Get lifetime ranking leaderboard for teachers (Never resets)
  Future<List<Map<String, dynamic>>> getLifetimeLeaderboard({
    int limit = 50,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('teacher_lifetime_ranking')
          .orderBy('badgePriorityScore', descending: true)
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

  /// Private helper method to transition seasonal metrics safely without resetting lifetime metrics
  Future<void> _handleSeasonTransition(SeasonModel newSeason) async {
    try {
      // Deactivate older active seasons
      final oldActiveSeasons = await _firestore
          .collection('seasons')
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();

      for (var doc in oldActiveSeasons.docs) {
        if (doc.id != newSeason.id) {
          batch.update(doc.reference, {'isActive': false});
        }
      }

      await batch.commit();

      // Update currentSeason field in teacher models without clearing lifetime rating
      final teachers = await _firestore.collection('teachers').get();
      for (var teacherDoc in teachers.docs) {
        final data = teacherDoc.data();
        double currentRating = (data['averageRating'] as num?)?.toDouble() ?? 0.0;

        await _firestore.collection('teachers').doc(teacherDoc.id).update({
          'currentSeason': newSeason.name.displayName,
          'lastSeasonRating': currentRating,
        });

        // Initialize entry in teacher_season_ranking
        await _firestore
            .collection('teacher_season_ranking')
            .doc('${teacherDoc.id}_${newSeason.id}')
            .set({
          'teacherId': teacherDoc.id,
          'teacherName': data['name'] ?? '',
          'seasonId': newSeason.id,
          'seasonName': newSeason.name.displayName,
          'seasonalRating': currentRating,
          'reviewCount': (data['reviewCount'] as num?)?.toInt() ?? 0,
          'highestBadgeType': data['highestBadgeType'] ?? 'verified',
          'lastUpdated': Timestamp.now(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error handling season transition: $e");
    }
  }
}
