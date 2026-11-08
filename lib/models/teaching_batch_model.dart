import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class TeachingBatchModel {
  final String id;
  final String teacherId;
  final String locationId;
  final String batchName;
  final String subject;
  final String classLevel;
  final int maxStudents;
  final int enrolledStudents;
  final double monthlyFee;
  final String teachingMode;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TeachingBatchModel({
    required this.id,
    required this.teacherId,
    required this.locationId,
    required this.batchName,
    required this.subject,
    required this.classLevel,
    this.maxStudents = 20,
    this.enrolledStudents = 0,
    this.monthlyFee = 0.0,
    this.teachingMode = 'offline',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to safely parse Firestore document snapshots or maps.
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
      teacherId: map['teacherId'] as String? ?? '',
      locationId: map['locationId'] as String? ?? '',
      batchName: map['batchName'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      classLevel: map['classLevel'] as String? ?? '',
      maxStudents: (map['maxStudents'] as num?)?.toInt() ?? 20,
      enrolledStudents: (map['enrolledStudents'] as num?)?.toInt() ?? 0,
      monthlyFee: (map['monthlyFee'] as num?)?.toDouble() ?? 0.0,
      teachingMode: map['teachingMode'] as String? ?? 'offline',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }

  /// Converts this model instance into a Map for Firestore write/update operations.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'teacherId': teacherId,
      'locationId': locationId,
      'batchName': batchName,
      'subject': subject,
      'classLevel': classLevel,
      'maxStudents': maxStudents,
      'enrolledStudents': enrolledStudents,
      'monthlyFee': monthlyFee,
      'teachingMode': teachingMode,
      'isActive': isActive,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// Creates a copy of the current batch with replaced properties.
  TeachingBatchModel copyWith({
    String? id,
    String? teacherId,
    String? locationId,
    String? batchName,
    String? subject,
    String? classLevel,
    int? maxStudents,
    int? enrolledStudents,
    double? monthlyFee,
    String? teachingMode,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeachingBatchModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      locationId: locationId ?? this.locationId,
      batchName: batchName ?? this.batchName,
      subject: subject ?? this.subject,
      classLevel: classLevel ?? this.classLevel,
      maxStudents: maxStudents ?? this.maxStudents,
      enrolledStudents: enrolledStudents ?? this.enrolledStudents,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      teachingMode: teachingMode ?? this.teachingMode,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculates the count of available seats remaining.
  int get availableSeats => maxStudents - enrolledStudents;

  /// Returns true if the batch has reached or exceeded max capacity.
  bool get isFull => enrolledStudents >= maxStudents;

  /// Returns a user-friendly seat status string for UI cards and badges.
  String get seatStatusDisplay {
    if (!isActive) {
      return 'Inactive';
    }
    if (isFull) {
      return 'Full';
    }
    final int seats = availableSeats;
    if (seats <= 5) {
      return '$seats ${seats == 1 ? "seat" : "seats"} left';
    }
    return '$seats seats available';
  }

  @override
  String toString() {
    return 'TeachingBatchModel(id: $id, teacherId: $teacherId, locationId: $locationId, '
        'batchName: $batchName, subject: $subject, classLevel: $classLevel, '
        'maxStudents: $maxStudents, enrolledStudents: $enrolledStudents, '
        'monthlyFee: $monthlyFee, teachingMode: $teachingMode, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TeachingBatchModel &&
        other.id == id &&
        other.teacherId == teacherId &&
        other.locationId == locationId &&
        other.batchName == batchName &&
        other.subject == subject &&
        other.classLevel == classLevel &&
        other.maxStudents == maxStudents &&
        other.enrolledStudents == enrolledStudents &&
        other.monthlyFee == monthlyFee &&
        other.teachingMode == teachingMode &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      teacherId,
      locationId,
      batchName,
      subject,
      classLevel,
      maxStudents,
      enrolledStudents,
      monthlyFee,
      teachingMode,
      isActive,
      createdAt,
      updatedAt,
    );
  }
}