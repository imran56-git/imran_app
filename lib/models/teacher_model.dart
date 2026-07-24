import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class TeacherModel extends Equatable {
  final String id;
  final String name;
  final bool isOnline;
  final DateTime lastSeen;
  final bool isTyping;
  final bool isVerified;
  final bool hasSpecialBadge;

  // Rating and Verification System Fields
  final double averageRating;
  final int ratingCount;
  final String currentSeason;
  final int verifiedStudents;
  final double lastSeasonRating;
  final double allTimeRating;
  final double responseRate;
  final int reviewCount;

  // New Badge & Ranking Integration Fields
  final String highestBadgeType; // 'verified', 'golden', 'master'
  final int badgePriorityScore; // Master (3), Golden (2), Verified (1), None (0)

  const TeacherModel({
    required this.id,
    required this.name,
    required this.isOnline,
    required this.lastSeen,
    required this.isTyping,
    required this.isVerified,
    required this.hasSpecialBadge,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    this.currentSeason = "Season 1",
    this.verifiedStudents = 0,
    this.lastSeasonRating = 0.0,
    this.allTimeRating = 0.0,
    this.responseRate = 0.0,
    this.reviewCount = 0,
    this.highestBadgeType = 'verified',
    this.badgePriorityScore = 1,
  });

  factory TeacherModel.fromMap(Map<String, dynamic> map, String docId) {
    return TeacherModel(
      id: docId,
      name: map['name'] ?? '',
      isOnline: map['isOnline'] ?? false,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isTyping: map['isTyping'] ?? false,
      isVerified: map['isVerified'] ?? false,
      hasSpecialBadge: map['hasSpecialBadge'] ?? false,
      // Safely mapping rating fields
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      currentSeason: map['currentSeason'] ?? "Season 1",
      verifiedStudents: (map['verifiedStudents'] as num?)?.toInt() ?? 0,
      lastSeasonRating: (map['lastSeasonRating'] as num?)?.toDouble() ?? 0.0,
      allTimeRating: (map['allTimeRating'] as num?)?.toDouble() ?? 0.0,
      responseRate: (map['responseRate'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      // Safely mapping badge ranking fields
      highestBadgeType: map['highestBadgeType'] ?? 'verified',
      badgePriorityScore: (map['badgePriorityScore'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isOnline': isOnline,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isTyping': isTyping,
      'isVerified': isVerified,
      'hasSpecialBadge': hasSpecialBadge,
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'currentSeason': currentSeason,
      'verifiedStudents': verifiedStudents,
      'lastSeasonRating': lastSeasonRating,
      'allTimeRating': allTimeRating,
      'responseRate': responseRate,
      'reviewCount': reviewCount,
      'highestBadgeType': highestBadgeType,
      'badgePriorityScore': badgePriorityScore,
    };
  }

  TeacherModel copyWith({
    String? id,
    String? name,
    bool? isOnline,
    DateTime? lastSeen,
    bool? isTyping,
    bool? isVerified,
    bool? hasSpecialBadge,
    double? averageRating,
    int? ratingCount,
    String? currentSeason,
    int? verifiedStudents,
    double? lastSeasonRating,
    double? allTimeRating,
    double? responseRate,
    int? reviewCount,
    String? highestBadgeType,
    int? badgePriorityScore,
  }) {
    return TeacherModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      isTyping: isTyping ?? this.isTyping,
      isVerified: isVerified ?? this.isVerified,
      hasSpecialBadge: hasSpecialBadge ?? this.hasSpecialBadge,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      currentSeason: currentSeason ?? this.currentSeason,
      verifiedStudents: verifiedStudents ?? this.verifiedStudents,
      lastSeasonRating: lastSeasonRating ?? this.lastSeasonRating,
      allTimeRating: allTimeRating ?? this.allTimeRating,
      responseRate: responseRate ?? this.responseRate,
      reviewCount: reviewCount ?? this.reviewCount,
      highestBadgeType: highestBadgeType ?? this.highestBadgeType,
      badgePriorityScore: badgePriorityScore ?? this.badgePriorityScore,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        isOnline,
        lastSeen,
        isTyping,
        isVerified,
        hasSpecialBadge,
        averageRating,
        ratingCount,
        currentSeason,
        verifiedStudents,
        lastSeasonRating,
        allTimeRating,
        responseRate,
        reviewCount,
        highestBadgeType,
        badgePriorityScore,
      ];
}
