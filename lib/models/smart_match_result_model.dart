import 'package:cloud_firestore/cloud_firestore.dart';

class SmartMatchResultModel {
  final String teacherId;
  final String teacherName;
  final String? teacherPhotoUrl;
  final String locationId;
  final String locationName;
  final String locationAddress;
  final double matchScore; // 0.0 to 100.0
  final double straightLineDistanceKm;
  final double roadDistanceKm;
  final int estimatedTravelMinutes;
  final String travelMode; // 'driving', 'walking', 'transit'
  final List<String> matchingReasons;
  final List<String> matchingSubjects;
  final List<String> matchingClasses;
  final List<String> matchingBatchIds;
  final bool hasSeatAvailable;
  final String teachingMode; // 'offline', 'online', 'hybrid'
  final bool isTeacherVerified;
  final double teacherRating;
  final DateTime calculatedAt;

  const SmartMatchResultModel({
    required this.teacherId,
    required this.teacherName,
    this.teacherPhotoUrl,
    required this.locationId,
    required this.locationName,
    required this.locationAddress,
    this.matchScore = 0.0,
    this.straightLineDistanceKm = 0.0,
    this.roadDistanceKm = 0.0,
    this.estimatedTravelMinutes = 0,
    this.travelMode = 'driving',
    this.matchingReasons = const [],
    this.matchingSubjects = const [],
    this.matchingClasses = const [],
    this.matchingBatchIds = const [],
    this.hasSeatAvailable = false,
    this.teachingMode = 'offline',
    this.isTeacherVerified = false,
    this.teacherRating = 0.0,
    required this.calculatedAt,
  });

  /// Factory constructor to instantiate model from a Map
  factory SmartMatchResultModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    int parseInt(dynamic value, [int defaultValue = 0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    List<String> parseStringList(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      return const [];
    }

    return SmartMatchResultModel(
      teacherId: map['teacherId']?.toString() ?? '',
      teacherName: map['teacherName']?.toString() ?? '',
      teacherPhotoUrl: map['teacherPhotoUrl']?.toString(),
      locationId: map['locationId']?.toString() ?? '',
      locationName: map['locationName']?.toString() ?? '',
      locationAddress: map['locationAddress']?.toString() ?? '',
      matchScore: parseDouble(map['matchScore']),
      straightLineDistanceKm: parseDouble(map['straightLineDistanceKm']),
      roadDistanceKm: parseDouble(map['roadDistanceKm']),
      estimatedTravelMinutes: parseInt(map['estimatedTravelMinutes']),
      travelMode: map['travelMode']?.toString() ?? 'driving',
      matchingReasons: parseStringList(map['matchingReasons']),
      matchingSubjects: parseStringList(map['matchingSubjects']),
      matchingClasses: parseStringList(map['matchingClasses']),
      matchingBatchIds: parseStringList(map['matchingBatchIds']),
      hasSeatAvailable: map['hasSeatAvailable'] is bool
          ? map['hasSeatAvailable'] as bool
          : false,
      teachingMode: map['teachingMode']?.toString() ?? 'offline',
      isTeacherVerified: map['isTeacherVerified'] is bool
          ? map['isTeacherVerified'] as bool
          : false,
      teacherRating: parseDouble(map['teacherRating']),
      calculatedAt: parseDateTime(map['calculatedAt']),
    );
  }

  /// Converts the instance to a Firestore-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'teacherName': teacherName,
      'teacherPhotoUrl': teacherPhotoUrl,
      'locationId': locationId,
      'locationName': locationName,
      'locationAddress': locationAddress,
      'matchScore': matchScore,
      'straightLineDistanceKm': straightLineDistanceKm,
      'roadDistanceKm': roadDistanceKm,
      'estimatedTravelMinutes': estimatedTravelMinutes,
      'travelMode': travelMode,
      'matchingReasons': matchingReasons,
      'matchingSubjects': matchingSubjects,
      'matchingClasses': matchingClasses,
      'matchingBatchIds': matchingBatchIds,
      'hasSeatAvailable': hasSeatAvailable,
      'teachingMode': teachingMode,
      'isTeacherVerified': isTeacherVerified,
      'teacherRating': teacherRating,
      'calculatedAt': Timestamp.fromDate(calculatedAt),
    };
  }

  /// Creates a copy of the model with updated fields
  SmartMatchResultModel copyWith({
    String? teacherId,
    String? teacherName,
    String? teacherPhotoUrl,
    String? locationId,
    String? locationName,
    String? locationAddress,
    double? matchScore,
    double? straightLineDistanceKm,
    double? roadDistanceKm,
    int? estimatedTravelMinutes,
    String? travelMode,
    List<String>? matchingReasons,
    List<String>? matchingSubjects,
    List<String>? matchingClasses,
    List<String>? matchingBatchIds,
    bool? hasSeatAvailable,
    String? teachingMode,
    bool? isTeacherVerified,
    double? teacherRating,
    DateTime? calculatedAt,
  }) {
    return SmartMatchResultModel(
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      teacherPhotoUrl: teacherPhotoUrl ?? this.teacherPhotoUrl,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      locationAddress: locationAddress ?? this.locationAddress,
      matchScore: matchScore ?? this.matchScore,
      straightLineDistanceKm:
          straightLineDistanceKm ?? this.straightLineDistanceKm,
      roadDistanceKm: roadDistanceKm ?? this.roadDistanceKm,
      estimatedTravelMinutes:
          estimatedTravelMinutes ?? this.estimatedTravelMinutes,
      travelMode: travelMode ?? this.travelMode,
      matchingReasons: matchingReasons ?? this.matchingReasons,
      matchingSubjects: matchingSubjects ?? this.matchingSubjects,
      matchingClasses: matchingClasses ?? this.matchingClasses,
      matchingBatchIds: matchingBatchIds ?? this.matchingBatchIds,
      hasSeatAvailable: hasSeatAvailable ?? this.hasSeatAvailable,
      teachingMode: teachingMode ?? this.teachingMode,
      isTeacherVerified: isTeacherVerified ?? this.isTeacherVerified,
      teacherRating: teacherRating ?? this.teacherRating,
      calculatedAt: calculatedAt ?? this.calculatedAt,
    );
  }

  // Getters & Helper Methods
  String get displayScore => '${matchScore.round()}%';

  String get matchBadgeLabel {
    if (matchScore >= 90.0) return 'Excellent Match';
    if (matchScore >= 75.0) return 'Great Match';
    if (matchScore >= 60.0) return 'Good Match';
    return 'Moderate Match';
  }

  String get displayRoadDistance => '${roadDistanceKm.toStringAsFixed(1)} KM';

  String get displayTravelTime {
    if (estimatedTravelMinutes < 60) {
      return '$estimatedTravelMinutes mins';
    }
    final int hours = estimatedTravelMinutes ~/ 60;
    final int minutes = estimatedTravelMinutes % 60;
    return minutes == 0 ? '$hours hr' : '$hours hr $minutes mins';
  }

  bool get isTopMatch => matchScore >= 85.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartMatchResultModel &&
          runtimeType == other.runtimeType &&
          teacherId == other.teacherId &&
          locationId == other.locationId &&
          calculatedAt == other.calculatedAt;

  @override
  int get hashCode => Object.hash(teacherId, locationId, calculatedAt);

  @override
  String toString() {
    return 'SmartMatchResultModel(teacherId: $teacherId, teacherName: $teacherName, locationId: $locationId, matchScore: $matchScore, roadDistanceKm: $roadDistanceKm, hasSeatAvailable: $hasSeatAvailable)';
  }
}