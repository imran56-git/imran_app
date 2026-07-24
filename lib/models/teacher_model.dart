import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherModel {
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

  TeacherModel({
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
      // Mapping new rating fields safely
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      currentSeason: map['currentSeason'] ?? "Season 1",
      verifiedStudents: (map['verifiedStudents'] as num?)?.toInt() ?? 0,
      lastSeasonRating: (map['lastSeasonRating'] as num?)?.toDouble() ?? 0.0,
      allTimeRating: (map['allTimeRating'] as num?)?.toDouble() ?? 0.0,
      responseRate: (map['responseRate'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
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
      // Exporting rating fields to Firestore
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'currentSeason': currentSeason,
      'verifiedStudents': verifiedStudents,
      'lastSeasonRating': lastSeasonRating,
      'allTimeRating': allTimeRating,
      'responseRate': responseRate,
      'reviewCount': reviewCount,
    };
  }
}
