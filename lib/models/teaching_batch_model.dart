import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class TeachingBatchModel {
  final String id;
  final String locationId;
  final String teacherId;
  final String batchName;
  final String subject;
  final String classLevel;
  final String startTime;
  final String endTime;
  final List<String> teachingDays;
  final int capacity;
  final int enrolledCount;
  final String availabilityStatus;
  final bool isActive;
  final String additionalNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TeachingBatchModel({
    required this.id,
    required this.locationId,
    required this.teacherId,
    required this.batchName,
    required this.subject,
    required this.classLevel,
    required this.startTime,
    required this.endTime,
    this.teachingDays = const <String>[],
    this.capacity = 20,
    this.enrolledCount = 0,
    this.availabilityStatus = 'available',
    this.isActive = true,
    this.additionalNotes = '',
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to instantiate a [TeachingBatchModel] from Firestore document data.
  factory TeachingBatchModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value);
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return null;
    }

    return TeachingBatchModel(
      id: docId.isNotEmpty ? docId : (map['id'] as String? ?? ''),
      locationId: map['locationId'] as String? ?? '',
      teacherId: map['teacherId'] as String? ?? '',
      batchName: map['batchName'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      classLevel: map['classLevel'] as String? ?? '',
      startTime: map['startTime'] as String? ?? '',
      endTime: map['endTime'] as String? ?? '',
      teachingDays: (map['teachingDays'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const <String>[],
      capacity: (map['capacity'] as num?)?.toInt() ?? 20,
      enrolledCount: (map['enrolledCount'] as num?)?.toInt() ?? 0,
      availabilityStatus: map['availabilityStatus'] as String? ?? 'available',
      isActive: map['isActive'] as bool? ?? true,
      additionalNotes: map['additionalNotes'] as String? ?? '',
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }

  /// Converts the model instance into a Map suitable for Firestore serialization.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'locationId': locationId,
      'teacherId': teacherId,
      'batchName': batchName,
      'subject': subject,
      'classLevel': classLevel,
      'startTime': startTime,
      'endTime': endTime,
      'teachingDays': teachingDays,
      'capacity': capacity,
      'enrolledCount': enrolledCount,
      'availabilityStatus': availabilityStatus,
      'isActive': isActive,
      'additionalNotes': additionalNotes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Creates a copy of this model with optional updated values.
  TeachingBatchModel copyWith({
    String? id,
    String? locationId,
    String? teacherId,
    String? batchName,
    String? subject,
    String? classLevel,
    String? startTime,
    String? endTime,
    List<String>? teachingDays,
    int? capacity,
    int? enrolledCount,
    String? availabilityStatus,
    bool? isActive,
    String? additionalNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeachingBatchModel(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      teacherId: teacherId ?? this.teacherId,
      batchName: batchName ?? this.batchName,
      subject: subject ?? this.subject,
      classLevel: classLevel ?? this.classLevel,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      teachingDays: teachingDays ?? this.teachingDays,
      capacity: capacity ?? this.capacity,
      enrolledCount: enrolledCount ?? this.enrolledCount,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      isActive: isActive ?? this.isActive,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Indicates if this batch has available seats for enrollment.
  bool get hasAvailableSeats => enrolledCount < capacity && isActive;

  /// Calculates the count of remaining seats clamped to the capacity range.
  int get remainingSeats => (capacity - enrolledCount).clamp(0, capacity);

  /// Human-readable timing representation.
  String get displayTiming => '$startTime – $endTime';

  /// Formatted summary of scheduled teaching days.
  String get daysSummary =>
      teachingDays.isEmpty ? 'Flexible days' : teachingDays.join(', ');

  /// Checks if the batch has reached or exceeded max capacity.
  bool get isFull => enrolledCount >= capacity;

  @override
  String toString() {
    return 'TeachingBatchModel(id: $id, locationId: $locationId, teacherId: $teacherId, '
        'batchName: $batchName, subject: $subject, classLevel: $classLevel, '
        'timing: $displayTiming, enrolled: $enrolledCount/$capacity, '
        'status: $availabilityStatus, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TeachingBatchModel &&
        other.id == id &&
        other.locationId == locationId &&
        other.teacherId == teacherId &&
        other.batchName == batchName &&
        other.subject == subject &&
        other.classLevel == classLevel &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        listEquals(other.teachingDays, teachingDays) &&
        other.capacity == capacity &&
        other.enrolledCount == enrolledCount &&
        other.availabilityStatus == availabilityStatus &&
        other.isActive == isActive &&
        other.additionalNotes == additionalNotes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      locationId,
      teacherId,
      batchName,
      subject,
      classLevel,
      startTime,
      endTime,
      Object.hashAll(teachingDays),
      capacity,
      enrolledCount,
      availabilityStatus,
      isActive,
      additionalNotes,
      createdAt,
      updatedAt,
    );
  }
}