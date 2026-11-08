import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/teacher_location_model.dart';
import '../models/teaching_batch_model.dart';
import '../models/teaching_schedule_model.dart';

class TeacherLocationService {
  final FirebaseFirestore _firestore;

  TeacherLocationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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
  /// Sets createdAt/updatedAt and records an audit log.
  Future<String> addTeachingLocation(TeacherLocationModel location) async {
    final CollectionReference<Map<String, dynamic>> ref =
        _locationsRef(location.teacherId);
    final DocumentReference<Map<String, dynamic>> docRef =
        location.id.isEmpty ? ref.doc() : ref.doc(location.id);

    final now = DateTime.now();
    final updatedModel = location.copyWith(
      id: docRef.id,
      createdAt: location.createdAt ?? now,
      updatedAt: now,
      isDeleted: false,
    );

    final data = updatedModel.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.set(data);

    await _recordLocationHistory(
      teacherId: location.teacherId,
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

  /// Updates existing location fields, updates updatedAt, and records audit history.
  Future<void> updateTeachingLocation(TeacherLocationModel location) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        _locationsRef(location.teacherId).doc(location.id);

    final data = location.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.update(data);

    await _recordLocationHistory(
      teacherId: location.teacherId,
      locationId: location.id,
      action: 'LOCATION_UPDATED',
      details: {
        'locationName': location.locationName,
        'isActive': location.isActive,
      },
    );
  }

  /// Toggles active status without deleting the location.
  Future<void> toggleLocationActiveStatus(
    String teacherId,
    String locationId,
    bool isActive,
  ) async {
    await _locationsRef(teacherId).doc(locationId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _recordLocationHistory(
      teacherId: teacherId,
      locationId: locationId,
      action: isActive ? 'LOCATION_ACTIVATED' : 'LOCATION_DEACTIVATED',
      details: {'isActive': isActive},
    );
  }

  /// Soft deletes a location document.
  Future<void> softDeleteTeachingLocation(
    String teacherId,
    String locationId,
  ) async {
    await _locationsRef(teacherId).doc(locationId).update({
      'isDeleted': true,
      'isActive': false,
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _recordLocationHistory(
      teacherId: teacherId,
      locationId: locationId,
      action: 'LOCATION_SOFT_DELETED',
      details: {'isDeleted': true},
    );
  }

  /// Restores a soft-deleted location document within recovery window.
  Future<void> restoreTeachingLocation(
    String teacherId,
    String locationId,
  ) async {
    await _locationsRef(teacherId).doc(locationId).update({
      'isDeleted': false,
      'isActive': true,
      'deletedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _recordLocationHistory(
      teacherId: teacherId,
      locationId: locationId,
      action: 'LOCATION_RESTORED',
      details: {'isDeleted': false},
    );
  }

  /// Permanently deletes the location document and all its subcollections.
  Future<void> permanentlyDeleteTeachingLocation(
    String teacherId,
    String locationId,
  ) async {
    final WriteBatch batch = _firestore.batch();

    // 1. Delete all batches sub-collection documents
    final batchesSnapshot = await _batchesRef(teacherId, locationId).get();
    for (final doc in batchesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // 2. Delete all schedules sub-collection documents
    final schedulesSnapshot = await _schedulesRef(teacherId, locationId).get();
    for (final doc in schedulesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // 3. Delete parent location document
    final docRef = _locationsRef(teacherId).doc(locationId);
    batch.delete(docRef);

    await batch.commit();

    await _recordLocationHistory(
      teacherId: teacherId,
      locationId: locationId,
      action: 'LOCATION_PERMANENTLY_DELETED',
      details: {'locationId': locationId},
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
    Query<Map<String, dynamic>> query = _locationsRef(teacherId)
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
    final ref = _batchesRef(batch.teacherId, batch.locationId);
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
    final data = batch.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await _batchesRef(batch.teacherId, batch.locationId)
        .doc(batch.id)
        .update(data);
  }

  /// Deletes a batch document.
  Future<void> deleteBatch(
    String teacherId,
    String locationId,
    String batchId,
  ) async {
    await _batchesRef(teacherId, locationId).doc(batchId).delete();
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

  // ==========================================
  // SECTION D: SCHEDULE MANAGEMENT
  // ==========================================

  /// Adds a schedule slot for a given location.
  Future<String> addScheduleSlot(TeachingScheduleModel schedule) async {
    final ref = _schedulesRef(schedule.teacherId, schedule.locationId);
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
    final data = schedule.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();

    await _schedulesRef(schedule.teacherId, schedule.locationId)
        .doc(schedule.id)
        .update(data);
  }

  /// Deletes a schedule slot.
  Future<void> deleteScheduleSlot(
    String teacherId,
    String locationId,
    String scheduleId,
  ) async {
    await _schedulesRef(teacherId, locationId).doc(scheduleId).delete();
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
