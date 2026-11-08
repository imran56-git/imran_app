import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/teacher_location_model.dart';
import '../models/teaching_batch_model.dart';
import '../models/teaching_schedule_model.dart';
import '../models/smart_match_result_model.dart';
import '../services/google_maps_route_service.dart';
import '../services/location_service.dart';

/// Filter & criteria input payload for FYBTT Smart Match Engine.
class SmartMatchCriteria {
  final double studentLat;
  final double studentLng;
  final double maxRadiusKm;
  final List<String> targetSubjects;
  final String? targetClass;
  final String? preferredTeachingMode; // 'offline', 'online', 'hybrid', or null
  final List<String>? preferredDays; // e.g. ['Monday', 'Wednesday']
  final String? preferredSlotType; // 'morning', 'afternoon', 'evening', or null
  final String? customStartTime; // e.g. '07:00 AM'
  final String? customEndTime; // e.g. '10:00 AM'
  final bool requireAvailableSeatsOnly;
  final String travelMode; // 'driving', 'walking', 'transit'

  const SmartMatchCriteria({
    required this.studentLat,
    required this.studentLng,
    this.maxRadiusKm = 10.0,
    required this.targetSubjects,
    this.targetClass,
    this.preferredTeachingMode,
    this.preferredDays,
    this.preferredSlotType,
    this.customStartTime,
    this.customEndTime,
    this.requireAvailableSeatsOnly = false,
    this.travelMode = 'driving',
  });

  SmartMatchCriteria copyWith({
    double? studentLat,
    double? studentLng,
    double? maxRadiusKm,
    List<String>? targetSubjects,
    String? targetClass,
    String? preferredTeachingMode,
    List<String>? preferredDays,
    String? preferredSlotType,
    String? customStartTime,
    String? customEndTime,
    bool? requireAvailableSeatsOnly,
    String? travelMode,
  }) {
    return SmartMatchCriteria(
      studentLat: studentLat ?? this.studentLat,
      studentLng: studentLng ?? this.studentLng,
      maxRadiusKm: maxRadiusKm ?? this.maxRadiusKm,
      targetSubjects: targetSubjects ?? this.targetSubjects,
      targetClass: targetClass ?? this.targetClass,
      preferredTeachingMode:
          preferredTeachingMode ?? this.preferredTeachingMode,
      preferredDays: preferredDays ?? this.preferredDays,
      preferredSlotType: preferredSlotType ?? this.preferredSlotType,
      customStartTime: customStartTime ?? this.customStartTime,
      customEndTime: customEndTime ?? this.customEndTime,
      requireAvailableSeatsOnly:
          requireAvailableSeatsOnly ?? this.requireAvailableSeatsOnly,
      travelMode: travelMode ?? this.travelMode,
    );
  }
}

/// Production-ready engine for intelligent teacher discovery,
/// schedule-aware matching, and route-based evaluation.
class SmartMatchService {
  final FirebaseFirestore _firestore;
  final LocationService _locationService;
  final GoogleMapsRouteService _routeService;

  SmartMatchService({
    FirebaseFirestore? firestore,
    LocationService? locationService,
    GoogleMapsRouteService? routeService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _locationService = locationService ?? LocationService(),
        _routeService = routeService ?? GoogleMapsRouteService();

  // ---------------------------------------------------------------------------
  // MAIN METHOD 1: Complete Smart Match Search
  // ---------------------------------------------------------------------------

  /// Performs full multi-stage matching against criteria:
  /// Stage 1: Geospatial radius pre-filter of active locations via Haversine.
  /// Stage 2: Batch and schedule fetch, compatibility checking & scoring (0 - 100).
  /// Stage 3: Top candidate road routing (distance & ETA) via Google Maps API.
  Future<List<SmartMatchResultModel>> findMatchingTeachers({
    required SmartMatchCriteria criteria,
    String? googleApiKey,
  }) async {
    try {
      // -----------------------------------------------------------------------
      // STAGE 1: Geospatial pre-filtering from Firestore
      // -----------------------------------------------------------------------
      final List<_CandidateLocation> candidates =
          await _fetchGeospatialCandidates(criteria);

      if (candidates.isEmpty) {
        return [];
      }

      // Group candidate locations by teacher to prevent redundant teacher fetches
      final Set<String> teacherIds =
          candidates.map((c) => c.location.teacherId).toSet();

      final Map<String, Map<String, dynamic>> teacherDataMap =
          await _batchFetchTeachers(teacherIds);

      // -----------------------------------------------------------------------
      // STAGE 2: Fetch Batches & Schedules, Score Compatibility
      // -----------------------------------------------------------------------
      final List<SmartMatchResultModel> preliminaryResults = [];

      for (final candidate in candidates) {
        final teacherId = candidate.location.teacherId;
        final teacherProfile = teacherDataMap[teacherId] ?? {};

        // Fetch batches belonging to this location & teacher
        final List<TeachingBatchModel> locationBatches =
            await _fetchBatchesForLocation(
          teacherId: teacherId,
          locationId: candidate.location.id,
        );

        // Fetch schedules for active batches at this location
        final List<TeachingScheduleModel> locationSchedules =
            await _fetchSchedulesForLocation(
          teacherId: teacherId,
          locationId: candidate.location.id,
        );

        // Compute compatibility & score
        final _ScoredCandidate scored = _calculateMatchScore(
          criteria: criteria,
          location: candidate.location,
          distanceKm: candidate.haversineDistanceKm,
          batches: locationBatches,
          schedules: locationSchedules,
          teacherProfile: teacherProfile,
        );

        // Discard candidates that have a 0 match score or fail required seat rules
        if (scored.totalScore <= 0.0) {
          continue;
        }

        if (criteria.requireAvailableSeatsOnly && scored.matchingBatches.isEmpty) {
          continue;
        }

        final teacherName = (teacherProfile['fullName'] ??
                teacherProfile['name'] ??
                'Teacher') as String;
        final teacherPhoto = teacherProfile['profileImageUrl'] ??
            teacherProfile['photoUrl'] as String?;
        final isVerified = (teacherProfile['isVerified'] ?? false) as bool;
        final rating =
            ((teacherProfile['rating'] ?? teacherProfile['averageRating'] ?? 0.0)
                    as num)
                .toDouble();
        final reviewCount =
            ((teacherProfile['reviewCount'] ?? teacherProfile['reviewsCount'] ?? 0)
                    as num)
                .toInt();

        preliminaryResults.add(
          SmartMatchResultModel(
            teacherId: teacherId,
            locationId: candidate.location.id,
            teacherName: teacherName,
            teacherPhotoUrl: teacherPhoto,
            isVerified: isVerified,
            rating: rating,
            reviewCount: reviewCount,
            location: candidate.location,
            matchingBatches: scored.matchingBatches,
            matchScore: double.parse(scored.totalScore.toStringAsFixed(1)),
            matchingReasons: scored.reasons,
            distanceKm: double.parse(candidate.haversineDistanceKm.toStringAsFixed(2)),
            travelDurationMinutes: null,
            travelDistanceText:
                '${candidate.haversineDistanceKm.toStringAsFixed(1)} km',
            travelDurationText: null,
          ),
        );
      }

      // Sort preliminary results by matchScore descending
      preliminaryResults.sort((a, b) => b.matchScore.compareTo(a.matchScore));

      // -----------------------------------------------------------------------
      // STAGE 3: Road Route Refinement for Top 10 Candidates
      // -----------------------------------------------------------------------
      const int topCandidatesLimit = 10;
      final int countToRoute = math.min(preliminaryResults.length, topCandidatesLimit);

      final List<SmartMatchResultModel> finalResults = [];

      for (int i = 0; i < preliminaryResults.length; i++) {
        final item = preliminaryResults[i];

        if (i < countToRoute) {
          try {
            final routeData = await _routeService.calculateRoadRoute(
              originLat: criteria.studentLat,
              originLng: criteria.studentLng,
              destLat: item.location.latitude,
              destLng: item.location.longitude,
              travelMode: criteria.travelMode,
              apiKey: googleApiKey,
            );

            if (routeData != null) {
              final roadDistanceKm = (routeData['distanceKm'] as num?)?.toDouble() ??
                  item.distanceKm;
              final durationMins = (routeData['durationMinutes'] as num?)?.toInt();
              final distanceText =
                  routeData['distanceText'] as String? ?? item.travelDistanceText;
              final durationText = routeData['durationText'] as String?;

              // Update distance reason if present
              final updatedReasons = List<String>.from(item.matchingReasons);
              if (durationText != null) {
                updatedReasons.add('Estimated $durationText road commute');
              }

              finalResults.add(
                item.copyWith(
                  distanceKm: roadDistanceKm,
                  travelDurationMinutes: durationMins,
                  travelDistanceText: distanceText,
                  travelDurationText: durationText,
                  matchingReasons: updatedReasons,
                ),
              );
              continue;
            }
          } catch (_) {
            // Road route calculation fallback silently keeps Haversine distance
          }
        }

        finalResults.add(item);
      }

      // Final sort: score descending, then distance ascending
      finalResults.sort((a, b) {
        final scoreComp = b.matchScore.compareTo(a.matchScore);
        if (scoreComp != 0) return scoreComp;
        return a.distanceKm.compareTo(b.distanceKm);
      });

      return finalResults;
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // MAIN METHOD 2: Schedule-Aware Finder Search
  // ---------------------------------------------------------------------------

  /// Dedicated Schedule-Aware finder targeting specific days, time slots, and optional subject.
  Future<List<SmartMatchResultModel>> searchBySchedule({
    required double studentLat,
    required double studentLng,
    required List<String> days,
    required String slotType,
    String? subject,
    String? classLevel,
    double maxRadiusKm = 10.0,
    String? googleApiKey,
  }) async {
    final criteria = SmartMatchCriteria(
      studentLat: studentLat,
      studentLng: studentLng,
      maxRadiusKm: maxRadiusKm,
      targetSubjects: subject != null && subject.trim().isNotEmpty
          ? [subject.trim()]
          : const [],
      targetClass: classLevel,
      preferredDays: days,
      preferredSlotType: slotType,
      requireAvailableSeatsOnly: false,
    );

    return findMatchingTeachers(
      criteria: criteria,
      googleApiKey: googleApiKey,
    );
  }

  // ---------------------------------------------------------------------------
  // SCORING ENGINE (Max 100 Points)
  // ---------------------------------------------------------------------------

  _ScoredCandidate _calculateMatchScore({
    required SmartMatchCriteria criteria,
    required TeacherLocationModel location,
    required double distanceKm,
    required List<TeachingBatchModel> batches,
    required List<TeachingScheduleModel> schedules,
    required Map<String, dynamic> teacherProfile,
  }) {
    double totalScore = 0.0;
    final List<String> reasons = [];
    final List<TeachingBatchModel> matchingBatches = [];

    // 1. SUBJECT MATCH (Max 30 Points)
    final teacherSubjects = _extractTeacherSubjects(location, teacherProfile, batches);
    if (criteria.targetSubjects.isNotEmpty) {
      int matchedCount = 0;
      final List<String> matchedSubjectNames = [];

      for (final reqSub in criteria.targetSubjects) {
        final hasMatch = teacherSubjects.any(
          (tSub) => tSub.toLowerCase().contains(reqSub.toLowerCase()) ||
              reqSub.toLowerCase().contains(tSub.toLowerCase()),
        );
        if (hasMatch) {
          matchedCount++;
          matchedSubjectNames.add(reqSub);
        }
      }

      final subjectScore =
          (matchedCount / criteria.targetSubjects.length) * 30.0;
      totalScore += subjectScore;

      if (matchedSubjectNames.isNotEmpty) {
        reasons.add('Teaches ${matchedSubjectNames.join(", ")}');
      }
    } else {
      // No specific subject required, award full baseline subject credit
      totalScore += 30.0;
    }

    // 2. CLASS / LEVEL MATCH (Max 20 Points)
    final teacherClasses = _extractTeacherClasses(location, teacherProfile, batches);
    if (criteria.targetClass != null && criteria.targetClass!.trim().isNotEmpty) {
      final reqClass = criteria.targetClass!.toLowerCase().trim();
      final hasClassMatch = teacherClasses.any(
        (c) => c.toLowerCase().trim() == reqClass ||
            c.toLowerCase().contains(reqClass) ||
            reqClass.contains(c.toLowerCase()),
      );

      if (hasClassMatch) {
        totalScore += 20.0;
        reasons.add('Offers curriculum for ${criteria.targetClass}');
      }
    } else {
      // No specific class requested, full baseline credit
      totalScore += 20.0;
    }

    // 3. PROXIMITY & DISTANCE (Max 25 Points)
    if (distanceKm <= criteria.maxRadiusKm) {
      // Linear proximity drop: 0 km = 25 pts, maxRadiusKm = 5 pts
      final proximityRatio =
          (criteria.maxRadiusKm - distanceKm) / criteria.maxRadiusKm;
      final distanceScore = 5.0 + (proximityRatio.clamp(0.0, 1.0) * 20.0);
      totalScore += distanceScore;
      reasons.add('Located ${distanceKm.toStringAsFixed(1)} km away');
    }

    // 4. SCHEDULE & BATCH COMPATIBILITY (Max 15 Points)
    double scheduleScore = 0.0;
    final normalizedReqDays =
        criteria.preferredDays?.map((d) => d.toLowerCase().trim()).toSet() ?? {};
    final reqSlotType = criteria.preferredSlotType?.toLowerCase().trim();

    for (final batch in batches) {
      if (!batch.isActive || batch.isDeleted) continue;

      bool batchEligible = true;

      // Filter by seat availability if requested
      if (criteria.requireAvailableSeatsOnly && batch.availableSeats <= 0) {
        batchEligible = false;
      }

      // Check teaching mode compatibility if specified
      if (criteria.preferredTeachingMode != null &&
          criteria.preferredTeachingMode!.isNotEmpty) {
        final mode = criteria.preferredTeachingMode!.toLowerCase();
        if (batch.teachingMode.toLowerCase() != mode &&
            batch.teachingMode.toLowerCase() != 'hybrid') {
          batchEligible = false;
        }
      }

      // Check slot type
      bool slotMatched = false;
      if (reqSlotType != null && reqSlotType.isNotEmpty) {
        if (batch.slotType.toLowerCase() == reqSlotType) {
          slotMatched = true;
        }
      } else {
        slotMatched = true;
      }

      // Check day matching
      bool dayMatched = false;
      if (normalizedReqDays.isNotEmpty) {
        final batchDays =
            batch.daysOfWeek.map((d) => d.toLowerCase().trim()).toSet();
        if (batchDays.intersection(normalizedReqDays).isNotEmpty) {
          dayMatched = true;
        }
      } else {
        dayMatched = true;
      }

      // Schedule sub-check
      final batchSchedules =
          schedules.where((s) => s.batchId == batch.id && s.isActive).toList();
      if (batchSchedules.isNotEmpty && normalizedReqDays.isNotEmpty) {
        final scheduleDays =
            batchSchedules.map((s) => s.dayOfWeek.toLowerCase().trim()).toSet();
        if (scheduleDays.intersection(normalizedReqDays).isNotEmpty) {
          dayMatched = true;
        }
      }

      if (batchEligible && (dayMatched || slotMatched)) {
        matchingBatches.add(batch);
      }
    }

    if (matchingBatches.isNotEmpty) {
      scheduleScore = 15.0;
      final sampleBatch = matchingBatches.first;
      reasons.add('Active batch: ${sampleBatch.batchName}');
      if (sampleBatch.availableSeats > 0) {
        reasons.add('${sampleBatch.availableSeats} seat(s) available now');
      }
    } else if (batches.isNotEmpty) {
      scheduleScore = 7.0; // Teacher has batches, but no exact slot/day match
      reasons.add('Has active batches available');
    } else {
      scheduleScore = 2.0; // General availability only
    }
    totalScore += scheduleScore;

    // 5. PROFILE CREDIBILITY & BADGES (Max 10 Points)
    double credibilityScore = 0.0;
    final isVerified = (teacherProfile['isVerified'] ?? false) as bool;
    final hasGoldenBadge = (teacherProfile['hasGoldenBadge'] ??
        teacherProfile['isTopRated'] ??
        false) as bool;
    final rating = ((teacherProfile['rating'] ??
            teacherProfile['averageRating'] ??
            0.0) as num)
        .toDouble();

    if (isVerified) {
      credibilityScore += 4.0;
      reasons.add('FYBTT Verified Tutor');
    }
    if (hasGoldenBadge) {
      credibilityScore += 3.0;
      reasons.add('Top Rated Badge Holder');
    }

    if (rating >= 4.5) {
      credibilityScore += 3.0;
    } else if (rating >= 4.0) {
      credibilityScore += 2.0;
    } else if (rating > 0.0) {
      credibilityScore += 1.0;
    }
    totalScore += credibilityScore;

    return _ScoredCandidate(
      totalScore: totalScore.clamp(0.0, 100.0),
      reasons: reasons,
      matchingBatches: matchingBatches,
    );
  }

  // ---------------------------------------------------------------------------
  // FIRESTORE FETCHERS & UTILITIES
  // ---------------------------------------------------------------------------

  /// Stage 1: Geospatial pre-fetch of active locations.
  Future<List<_CandidateLocation>> _fetchGeospatialCandidates(
    SmartMatchCriteria criteria,
  ) async {
    final List<_CandidateLocation> candidates = [];

    // Query active non-deleted locations
    QuerySnapshot snapshot;
    try {
      snapshot = await _firestore
          .collection('teaching_locations')
          .where('isActive', isEqualTo: true)
          .where('isDeleted', isEqualTo: false)
          .get();
    } catch (_) {
      // Fallback to teacher_locations collection name
      snapshot = await _firestore
          .collection('teacher_locations')
          .where('isActive', isEqualTo: true)
          .where('isDeleted', isEqualTo: false)
          .get();
    }

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final location = TeacherLocationModel.fromMap(data);

        if (location.latitude == 0.0 && location.longitude == 0.0) {
          continue;
        }

        // Filter preferred teaching mode at location level if specified
        if (criteria.preferredTeachingMode != null &&
            criteria.preferredTeachingMode!.isNotEmpty) {
          final mode = criteria.preferredTeachingMode!.toLowerCase();
          if (location.teachingMode.toLowerCase() != mode &&
              location.teachingMode.toLowerCase() != 'hybrid') {
            continue;
          }
        }

        // Calculate straight-line Haversine distance
        final distanceKm = _locationService.haversineDistance(
          criteria.studentLat,
          criteria.studentLng,
          location.latitude,
          location.longitude,
        );

        if (distanceKm <= criteria.maxRadiusKm) {
          candidates.add(
            _CandidateLocation(
              location: location,
              haversineDistanceKm: distanceKm,
            ),
          );
        }
      } catch (_) {
        // Skip malformed individual location docs safely
      }
    }

    return candidates;
  }

  /// Batch fetches teacher profiles for candidate locations.
  Future<Map<String, Map<String, dynamic>>> _batchFetchTeachers(
    Set<String> teacherIds,
  ) async {
    final Map<String, Map<String, dynamic>> results = {};
    if (teacherIds.isEmpty) return results;

    // Firestore allows max 10 elements in 'whereIn' queries
    final List<String> idList = teacherIds.toList();
    const int chunkSize = 10;

    for (int i = 0; i < idList.length; i += chunkSize) {
      final chunk = idList.sublist(
        i,
        math.min(i + chunkSize, idList.length),
      );

      try {
        final snap = await _firestore
            .collection('teachers')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snap.docs) {
          results[doc.id] = doc.data();
        }
      } catch (_) {
        // Continue querying remaining chunks
      }
    }

    return results;
  }

  /// Fetches batches associated with a specific location and teacher.
  Future<List<TeachingBatchModel>> _fetchBatchesForLocation({
    required String teacherId,
    required String locationId,
  }) async {
    try {
      final snap = await _firestore
          .collection('teaching_batches')
          .where('teacherId', isEqualTo: teacherId)
          .where('locationId', isEqualTo: locationId)
          .where('isActive', isEqualTo: true)
          .where('isDeleted', isEqualTo: false)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TeachingBatchModel.fromMap(data);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches schedules associated with a specific location and teacher.
  Future<List<TeachingScheduleModel>> _fetchSchedulesForLocation({
    required String teacherId,
    required String locationId,
  }) async {
    try {
      final snap = await _firestore
          .collection('teaching_schedules')
          .where('teacherId', isEqualTo: teacherId)
          .where('locationId', isEqualTo: locationId)
          .where('isActive', isEqualTo: true)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return TeachingScheduleModel.fromMap(data);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // DATA EXTRACTION HELPERS
  // ---------------------------------------------------------------------------

  Set<String> _extractTeacherSubjects(
    TeacherLocationModel location,
    Map<String, dynamic> teacherProfile,
    List<TeachingBatchModel> batches,
  ) {
    final Set<String> subjects = {};

    // 1. From batches
    for (final b in batches) {
      if (b.subject.trim().isNotEmpty) {
        subjects.add(b.subject.trim());
      }
    }

    // 2. From teacher profile
    final rawProfileSubjects =
        teacherProfile['subjects'] ?? teacherProfile['subjectSpecialties'];
    if (rawProfileSubjects is List) {
      for (final s in rawProfileSubjects) {
        if (s != null && s.toString().trim().isNotEmpty) {
          subjects.add(s.toString().trim());
        }
      }
    } else if (rawProfileSubjects is String &&
        rawProfileSubjects.trim().isNotEmpty) {
      subjects.add(rawProfileSubjects.trim());
    }

    return subjects;
  }

  Set<String> _extractTeacherClasses(
    TeacherLocationModel location,
    Map<String, dynamic> teacherProfile,
    List<TeachingBatchModel> batches,
  ) {
    final Set<String> classes = {};

    // 1. From batches
    for (final b in batches) {
      if (b.classLevel.trim().isNotEmpty) {
        classes.add(b.classLevel.trim());
      }
    }

    // 2. From teacher profile
    final rawClasses =
        teacherProfile['classesTaught'] ?? teacherProfile['classes'];
    if (rawClasses is List) {
      for (final c in rawClasses) {
        if (c != null && c.toString().trim().isNotEmpty) {
          classes.add(c.toString().trim());
        }
      }
    } else if (rawClasses is String && rawClasses.trim().isNotEmpty) {
      classes.add(rawClasses.trim());
    }

    return classes;
  }
}

// -----------------------------------------------------------------------------
// INTERNAL HELPER CLASSES
// -----------------------------------------------------------------------------

class _CandidateLocation {
  final TeacherLocationModel location;
  final double haversineDistanceKm;

  const _CandidateLocation({
    required this.location,
    required this.haversineDistanceKm,
  });
}

class _ScoredCandidate {
  final double totalScore;
  final List<String> reasons;
  final List<TeachingBatchModel> matchingBatches;

  const _ScoredCandidate({
    required this.totalScore,
    required this.reasons,
    required this.matchingBatches,
  });
}