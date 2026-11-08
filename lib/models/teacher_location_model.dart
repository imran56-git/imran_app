import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherLocationModel {
  final String id;
  final String teacherId;
  final String locationName;
  final String locationType; // 'tuition_centre', 'institute', 'home_tuition', 'school', 'other'
  final String fullAddress;
  final String? placeId;
  final double latitude;
  final double longitude;
  final String geohash;
  final String teachingMode; // 'offline', 'online', 'hybrid'
  final List<String> subjects;
  final List<String> classes;
  final String additionalNotes;
  final String verificationStatus; // 'verified', 'teacher_confirmed', 'pending'
  final bool isActive;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final double? serviceRadiusKm;

  const TeacherLocationModel({
    required this.id,
    required this.teacherId,
    required this.locationName,
    this.locationType = 'tuition_centre',
    String? fullAddress,
    String? address,
    this.placeId,
    required this.latitude,
    required this.longitude,
    required this.geohash,
    this.teachingMode = 'offline',
    this.subjects = const [],
    this.classes = const [],
    this.additionalNotes = '',
    this.verificationStatus = 'pending',
    this.isActive = true,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    double? serviceRadiusKm,
    double? radiusKm,
  })  : fullAddress = fullAddress ?? address ?? '',
        serviceRadiusKm = serviceRadiusKm ?? radiusKm;

  /// Factory constructor to instantiate model from Firestore map and document ID
  factory TeacherLocationModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    List<String> parseStringList(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      return const [];
    }

    return TeacherLocationModel(
      id: docId,
      teacherId: map['teacherId']?.toString() ?? '',
      locationName: map['locationName']?.toString() ?? '',
      locationType: map['locationType']?.toString() ?? 'tuition_centre',
      fullAddress: (map['fullAddress'] ?? map['address'])?.toString() ?? '',
      placeId: map['placeId']?.toString(),
      latitude: parseDouble(map['latitude']),
      longitude: parseDouble(map['longitude']),
      geohash: map['geohash']?.toString() ?? '',
      teachingMode: map['teachingMode']?.toString() ?? 'offline',
      subjects: parseStringList(map['subjects'] ?? map['subjectSpecialties']),
      classes: parseStringList(map['classes']),
      additionalNotes: map['additionalNotes']?.toString() ?? '',
      verificationStatus: map['verificationStatus']?.toString() ?? 'pending',
      isActive: map['isActive'] is bool ? map['isActive'] as bool : true,
      isDeleted: map['isDeleted'] is bool ? map['isDeleted'] as bool : false,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
      deletedAt: parseDateTime(map['deletedAt']),
      serviceRadiusKm: map['serviceRadiusKm'] != null
          ? parseDouble(map['serviceRadiusKm'])
          : (map['radiusKm'] != null ? parseDouble(map['radiusKm']) : null),
    );
  }

  /// Converts the instance to a Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'locationName': locationName,
      'locationType': locationType,
      'fullAddress': fullAddress,
      'address': fullAddress,
      'placeId': placeId,
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
      'teachingMode': teachingMode,
      'subjects': subjects,
      'subjectSpecialties': subjects,
      'classes': classes,
      'additionalNotes': additionalNotes,
      'verificationStatus': verificationStatus,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'serviceRadiusKm': serviceRadiusKm,
      'radiusKm': serviceRadiusKm,
    };
  }

  /// Creates a copy of the model with updated fields
  TeacherLocationModel copyWith({
    String? id,
    String? teacherId,
    String? locationName,
    String? locationType,
    String? fullAddress,
    String? address,
    String? placeId,
    double? latitude,
    double? longitude,
    String? geohash,
    String? teachingMode,
    List<String>? subjects,
    List<String>? classes,
    String? additionalNotes,
    String? verificationStatus,
    bool? isActive,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    double? serviceRadiusKm,
    double? radiusKm,
  }) {
    return TeacherLocationModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      locationName: locationName ?? this.locationName,
      locationType: locationType ?? this.locationType,
      fullAddress: fullAddress ?? address ?? this.fullAddress,
      placeId: placeId ?? this.placeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geohash: geohash ?? this.geohash,
      teachingMode: teachingMode ?? this.teachingMode,
      subjects: subjects ?? this.subjects,
      classes: classes ?? this.classes,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      serviceRadiusKm: serviceRadiusKm ?? radiusKm ?? this.serviceRadiusKm,
    );
  }

  // Backward-compatible Getters
  String get address => fullAddress;
  double? get radiusKm => serviceRadiusKm;
  bool get isVerified => verificationStatus == 'verified';
  List<String> get subjectSpecialties => subjects;

  // Helper Getters
  bool get isOfflineTeaching => teachingMode == 'offline' || teachingMode == 'hybrid';

  String get displayStatus =>
      isActive ? (verificationStatus == 'verified' ? 'Verified' : 'Active') : 'Inactive';

  bool get isHomeTuition => locationType == 'home_tuition';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherLocationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TeacherLocationModel(id: $id, teacherId: $teacherId, locationName: $locationName, fullAddress: $fullAddress, latitude: $latitude, longitude: $longitude, teachingMode: $teachingMode, verificationStatus: $verificationStatus, isActive: $isActive)';
  }
}
