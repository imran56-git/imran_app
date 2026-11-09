import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/teacher_location_model.dart';
import '../models/teaching_batch_model.dart';
import '../models/teaching_schedule_model.dart';

class TeacherLocationService {
  final FirebaseFirestore _firestore;

  TeacherLocationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Collection references helpers
  CollectionReference<Map<String, dynamic>> _locationsRef(String teacherId) =>
      _firestore.collection('teachers').doc(teacherId).collection('teachingLocations');

  CollectionReference<Map<String, dynamic>> _batchesRef(
    String teacherId,
    String locationId,
  ) =>
      _locationsRef(teacherId).doc(locationId).collection('batches');

  CollectionReference<Map<String, dynamic>> _schedulesRef(
    String teacherId,
    String locationId,
  ) =>
      _locationsRef(teacherId).doc(locationId).collection('schedules');

  CollectionReference<Map<String, dynamic>> _historyRef(String teacherId) =>
      _firestore.collection('teachers').doc(teacherId).collection('locationHistory');

  // ==========================================
  // SECTION A: LOCATION MANAGEMENT (CRUD)
  // ==========================================

  /// Adds a new location document under teachers/$teacherId/teachingLocations/
  Future<String> addTeachingLocation(TeacherLocationModel location) async {
    final tId = location.teacherId.isNotEmpty ? location.teacherId : _currentUid;
    final CollectionReference<Map<String, dynamic>> ref = _locationsRef(tId);
    final DocumentReference<Map<String, dynamic>> docRef =
        location.id.isEmpty ? ref.doc() : ref.doc(location.id);

    final now = DateTime.now();
    final updatedModel = location.copyWith(
      id: docRef.id,
      teacherId: tId,
      createdAt: location.createdAt ?? now,
      updatedAt: now,
      isDeleted: false,
    );

    final data = updatedModel.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.set(data);

    await _recordLocationHistory(
      teacherId: tId,
      locationId: docRef.id,
      action: 'LOCATION_CREATED',
      details: {
        'locationName': location.locationName,
        'fullAddress': location.fullAddress,
        'teachingMode': location.teachingMode,
      },
    );

    return docRef.id;
  }

  /// Alias for addTeachingLocation to support screens calling createTeachingLocation
  Future<String> createTeachingLocation(TeacherLocationModel location) =>
      addTeachingLocation(location);

  /// Updates existing location fields, updates updatedAt, and records audit history.
  Future<void> updateTeachingLocation(TeacherLocationModel location) async {
    final tId = location.teacherId.isNotEmpty ? location.teacherId : _currentUid;
    final DocumentReference<Map<String, dynamic>> docRef =
        _locationsRef(tId).doc(location.id);

    final data = location.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.update(data);

    await _recordLocationHistory(
      teacherId: tId,
      locationId: location.id,
      action: 'LOCATION_UPDATED',
      details: {
        'locationName': location.locationName,
        'isActive': location.isActive,
      },
    );
  }

  /// Toggles active status without deleting the location. Supports 2 or 3 arguments.
  Future<void> toggleLocationActiveStatus(
    dynamic arg1, [
    dynamic arg2,
    bool? arg3,
  ]) async {
    String tId = _currentUid;
    String locId = '';
    bool active = true;

    if (arg3 != null) {
      tId = arg1.toString();
      locId = arg2.toString();
      active = arg3;
    } else if (arg2 != null && arg2 is bool) {
      locId = arg1.toString();
      active = arg2;
    } else if (arg1 is TeacherLocationModel) {
      tId = arg1.teacherId.isNotEmpty ? arg1.teacherId : _currentUid;
      locId = arg1.id;
      active = arg2 is bool ? arg2 : !arg1.isActive;
    } else {
      locId = arg1.toString();
    }

    if (locId.isEmpty) return;

    await _locationsRef(tId).doc(locId).update({
      'isActive': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _recordLocationHistory(
      teacherId: tId,
      locationId: locId,
      action: active ? 'LOCATION_ACTIVATED' : 'LOCATION_DEACTIVATED',
      details: {'isActive': active},
    );
  }

  /// Soft deletes a location document. Supports calling with (locationId) or (teacherId, locationId).
  Future<void> softDeleteTeachingLocation(
    String arg1, [
    String? arg2,
  ]) async {
    final String tId = arg2 != null ? arg1 : _currentUid;
    final String locId = arg2 ?? arg1;

    await _locationsRef(tId).doc(locId).update({
      'isDeleted': true,
      'isActive': false,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _recordLocationHistory(
      teacherId: tId,
      locationId: locId,
      action: 'LOCATION_SOFT_DELETED',
      details: {'isDeleted': true},
    );
  }

  /// Restores a soft-deleted location document. Supports calling with (locationId) or (teacherId, locationId).
  Future<void> restoreTeachingLocation(
    String arg1, [
    String? arg2,
  ]) async {
    final String tId = arg2 != null ? arg1 : _currentUid;
    final String locId = arg2 ?? arg1;

    await _locationsRef(tId).doc(locId).update({
      'isDeleted': false,
      'isActive': true,
      'deletedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _recordLocationHistory(
      teacherId: tId,
      locationId: locId,
      action: 'LOCATION_RESTORED',
      details: {'isDeleted': false},
    );
  }

  /// Permanently deletes location document and its subcollections. Supports calling with (locationId) or (teacherId, locationId).
  Future<void> permanentlyDeleteTeachingLocation(
    String arg1, [
    String? arg2,
  ]) async {
    final String tId = arg2 != null ? arg1 : _currentUid;
    final String locId = arg2 ?? arg1;

    final WriteBatch batch = _firestore.batch();

    final batchesSnapshot = await _batchesRef(tId, locId).get();
    for (final doc in batchesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    final schedulesSnapshot = await _schedulesRef(tId, locId).get();
    for (final doc in schedulesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    final docRef = _locationsRef(tId).doc(locId);
    batch.delete(docRef);

    await batch.commit();

    await _recordLocationHistory(
      teacherId: tId,
      locationId: locId,
      action: 'LOCATION_PERMANENTLY_DELETED',
      details: {'locationId': locId},
    );
  }

  // ==========================================
  // SECTION B: REAL-TIME STREAMS & QUERIES
  // ==========================================

  /// Streams non-deleted teaching locations for teacher management screens.
  Stream<List<TeacherLocationModel>> getTeacherLocationsStream(
    String teacherId, {
    bool includeInactive = false,
  }) {
    final tId = teacherId.isNotEmpty ? teacherId : _currentUid;
    Query<Map<String, dynamic>> query = _locationsRef(tId)
        .where('isDeleted', isEqualTo: false);

    if (!includeInactive) {
      query = query.where('isActive', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => TeacherLocationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Streams soft-deleted teaching locations for recovery screens.
  Stream<List<TeacherLocationModel>> getDeletedTeacherLocationsStream(
    String teacherId,
  ) {
    final tId = teacherId.isNotEmpty ? teacherId : _currentUid;
    return _locationsRef(tId)
        .where('isDeleted', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TeacherLocationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Streams active, non-deleted locations for public profile viewers / students.
  Stream<List<TeacherLocationModel>> getPublicActiveLocationsStream(
    String teacherId,
  ) {
    return _locationsRef(teacherId)
        .where('isDeleted', isEqualTo: false)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TeacherLocationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Fetches a single location document by ID.
  Future<TeacherLocationModel?> getLocationById(
    String teacherId,
    String locationId,
  ) async {
    try {
      final doc = await _locationsRef(teacherId).doc(locationId).get();
      if (doc.exists && doc.data() != null) {
        return TeacherLocationModel.fromMap(doc.data()!, doc.id);
      }
    } catch (_) {}
    return null;
  }

  // ==========================================
  // SECTION C: BATCH MANAGEMENT
  // ==========================================

  /// Adds a new batch under location's batches subcollection.
  Future<String> addBatch(TeachingBatchModel batch) async {
    final tId = batch.teacherId.isNotEmpty ? batch.teacherId : _currentUid;
    final ref = _batchesRef(tId, batch.locationId);
    final docRef = batch.id.isEmpty ? ref.doc() : ref.doc(batch.id);

    final data = batch.toMap();
    data['id'] = docRef.id;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.set(data);
    return docRef.id;
  }

  /// Updates an existing batch.
  Future<void> updateBatch(TeachingBatchModel batch) async {
    final tId = batch.teacherId.isNotEmpty ? batch.teacherId : _currentUid;
    final data = batch.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await _batchesRef(tId, batch.locationId)
        .doc(batch.id)
        .update(data);
  }

  /// Deletes a batch document. Supports deleteBatch(batchId) or deleteBatch(teacherId, locationId, batchId).
  Future<void> deleteBatch(
    String arg1, [
    String? arg2,
    String? arg3,
  ]) async {
    if (arg3 != null && arg2 != null) {
      await _batchesRef(arg1, arg2).doc(arg3).delete();
    } else {
      // Search across collections via collectionGroup if only batchId was provided
      final query = await _firestore
          .collectionGroup('batches')
          .where('id', isEqualTo: arg1)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.delete();
      }
    }
  }

  /// Streams active batches for a location.
  Stream<List<TeachingBatchModel>> getBatchesStream(
    String teacherId,
    String locationId,
  ) {
    return _batchesRef(teacherId, locationId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => TeachingBatchModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Fetches batches list directly as a Future.
  Future<List<TeachingBatchModel>> getBatches(
    String teacherId,
    String locationId,
  ) async {
    try {
      final snapshot = await _batchesRef(teacherId, locationId).get();
      return snapshot.docs
          .map((doc) => TeachingBatchModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ==========================================
  // SECTION D: SCHEDULE MANAGEMENT
  // ==========================================

  /// Adds a schedule slot for a given location.
  Future<String> addScheduleSlot(TeachingScheduleModel schedule) async {
    final tId = schedule.teacherId.isNotEmpty ? schedule.teacherId : _currentUid;
    final ref = _schedulesRef(tId, schedule.locationId);
    final docRef = schedule.id.isEmpty ? ref.doc() : ref.doc(schedule.id);

    final data = schedule.toMap();
    data['id'] = docRef.id;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.set(data);
    return docRef.id;
  }

  /// Updates a schedule slot.
  Future<void> updateScheduleSlot(TeachingScheduleModel schedule) async {
    final tId = schedule.teacherId.isNotEmpty ? schedule.teacherId : _currentUid;
    final data = schedule.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await _schedulesRef(tId, schedule.locationId)
        .doc(schedule.id)
        .update(data);
  }

  /// Deletes a schedule slot. Supports deleteScheduleSlot(scheduleId) or deleteScheduleSlot(teacherId, locationId, scheduleId).
  Future<void> deleteScheduleSlot(
    String arg1, [
    String? arg2,
    String? arg3,
  ]) async {
    if (arg3 != null && arg2 != null) {
      await _schedulesRef(arg1, arg2).doc(arg3).delete();
    } else {
      // Search across collections via collectionGroup if only scheduleId was provided
      final query = await _firestore
          .collectionGroup('schedules')
          .where('id', isEqualTo: arg1)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.delete();
      }
    }
  }

  /// Streams schedules for a location.
  Stream<List<TeachingScheduleModel>> getSchedulesStream(
    String teacherId,
    String locationId,
  ) {
    return _schedulesRef(teacherId, locationId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => TeachingScheduleModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ==========================================
  // SECTION E: PROXIMITY & DUPLICATE PREVENTION
  // ==========================================

  /// Checks if the teacher already has an existing active location within [thresholdMeters].
  Future<bool> isDuplicateLocation({
    required String teacherId,
    required double latitude,
    required double longitude,
    double thresholdMeters = 50.0,
  }) async {
    try {
      final snapshot = await _locationsRef(teacherId)
          .where('isDeleted', isEqualTo: false)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final double? docLat = (data['latitude'] as num?)?.toDouble();
        final double? docLng = (data['longitude'] as num?)?.toDouble();

        if (docLat != null && docLng != null) {
          final double distanceMeters =
              _calculateHaversineDistanceMeters(latitude, longitude, docLat, docLng);

          if (distanceMeters <= thresholdMeters) {
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }

  // Helper audit logger
  Future<void> _recordLocationHistory({
    required String teacherId,
    required String locationId,
    required String action,
    required Map<String, dynamic> details,
  }) async {
    try {
      await _historyRef(teacherId).add({
        'locationId': locationId,
        'action': action,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Haversine distance helper in meters
  static double _calculateHaversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000.0;
    final double dLat = (lat2 - lat1) * (math.pi / 180.0);
    final double dLon = (lon2 - lon1) * (math.pi / 180.0);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }
}