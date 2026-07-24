import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Enum representing the priority levels and types of Teacher Badges
enum BadgeType {
  verified,
  golden,
  master;

  String toMapValue() {
    return name;
  }

  static BadgeType fromMapValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'master':
        return BadgeType.master;
      case 'golden':
        return BadgeType.golden;
      case 'verified':
      default:
        return BadgeType.verified;
    }
  }

  /// Priority score for sorting teachers in ranking system: Master (3) > Golden (2) > Verified (1)
  int get priority {
    switch (this) {
      case BadgeType.master:
        return 3;
      case BadgeType.golden:
        return 2;
      case BadgeType.verified:
        return 1;
    }
  }

  String get displayName {
    switch (this) {
      case BadgeType.master:
        return 'Master Teacher';
      case BadgeType.golden:
        return 'Golden Teacher';
      case BadgeType.verified:
        return 'Verified Teacher';
    }
  }

  String get assetPath {
    switch (this) {
      case BadgeType.master:
        return 'assets/badges/Master_Badge.png';
      case BadgeType.golden:
        return 'assets/badges/Golden_Batch.png';
      case BadgeType.verified:
        return 'assets/badges/Verified_Batch.png';
    }
  }
}

/// Class representing a badge assigned to a teacher along with unlock metadata.
class BadgeModel extends Equatable {
  final String id;
  final String teacherId;
  final BadgeType type;
  final DateTime unlockedAt;
  final bool isCurrentlyActive;
  final String assignedReason;

  const BadgeModel({
    required this.id,
    required this.teacherId,
    required this.type,
    required this.unlockedAt,
    this.isCurrentlyActive = true,
    required this.assignedReason,
  });

  factory BadgeModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return BadgeModel.fromMap(map, doc.id);
  }

  factory BadgeModel.fromMap(Map<String, dynamic> map, String docId) {
    return BadgeModel(
      id: docId,
      teacherId: map['teacherId'] ?? '',
      type: BadgeType.fromMapValue(map['type'] as String?),
      unlockedAt: (map['unlockedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCurrentlyActive: map['isCurrentlyActive'] ?? true,
      assignedReason: map['assignedReason'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'type': type.toMapValue(),
      'unlockedAt': Timestamp.fromDate(unlockedAt),
      'isCurrentlyActive': isCurrentlyActive,
      'assignedReason': assignedReason,
    };
  }

  BadgeModel copyWith({
    String? id,
    String? teacherId,
    BadgeType? type,
    DateTime? unlockedAt,
    bool? isCurrentlyActive,
    String? assignedReason,
  }) {
    return BadgeModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      type: type ?? this.type,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isCurrentlyActive: isCurrentlyActive ?? this.isCurrentlyActive,
      assignedReason: assignedReason ?? this.assignedReason,
    );
  }

  @override
  List<Object?> get props => [
        id,
        teacherId,
        type,
        unlockedAt,
        isCurrentlyActive,
        assignedReason,
      ];
}
