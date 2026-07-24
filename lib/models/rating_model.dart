import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String ratingId;
  final String teacherId;
  final String studentId;
  final double stars;
  final String review;
  final DateTime createdAt;
  final String season; // e.g. "Season 1", "Season 2", "Season 3", "Season 4"
  final bool isVerified;
  final String? teacherReply;
  final DateTime? teacherReplyTime;

  RatingModel({
    required this.ratingId,
    required this.teacherId,
    required this.studentId,
    required this.stars,
    required this.review,
    required this.createdAt,
    required this.season,
    this.isVerified = false,
    this.teacherReply,
    this.teacherReplyTime,
  });

  // Convert RatingModel instance to JSON Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'ratingId': ratingId,
      'teacherId': teacherId,
      'studentId': studentId,
      'stars': stars,
      'review': review,
      'createdAt': Timestamp.fromDate(createdAt),
      'season': season,
      'isVerified': isVerified,
      'teacherReply': teacherReply,
      'teacherReplyTime': teacherReplyTime != null
          ? Timestamp.fromDate(teacherReplyTime!)
          : null,
    };
  }

  // Create RatingModel instance from Firestore Document Snapshot / Map
  factory RatingModel.fromMap(Map<String, dynamic> map, String id) {
    return RatingModel(
      ratingId: id,
      teacherId: map['teacherId'] ?? '',
      studentId: map['studentId'] ?? '',
      stars: (map['stars'] as num?)?.toDouble() ?? 0.0,
      review: map['review'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      season: map['season'] ?? _getCurrentSeason(),
      isVerified: map['isVerified'] ?? false,
      teacherReply: map['teacherReply'],
      teacherReplyTime: (map['teacherReplyTime'] as Timestamp?)?.toDate(),
    );
  }

  // Helper method to automatically compute current season based on current month
  static String getCurrentSeason() {
    return _getCurrentSeason();
  }

  static String _getCurrentSeason() {
    final month = DateTime.now().month;
    if (month >= 1 && month <= 3) {
      return "Season 1";
    } else if (month >= 4 && month <= 6) {
      return "Season 2";
    } else if (month >= 7 && month <= 9) {
      return "Season 3";
    } else {
      return "Season 4";
    }
  }

  // Helper method for copying object with modified values
  RatingModel copyWith({
    String? ratingId,
    String? teacherId,
    String? studentId,
    double? stars,
    String? review,
    DateTime? createdAt,
    String? season,
    bool? isVerified,
    String? teacherReply,
    DateTime? teacherReplyTime,
  }) {
    return RatingModel(
      ratingId: ratingId ?? this.ratingId,
      teacherId: teacherId ?? this.teacherId,
      studentId: studentId ?? this.studentId,
      stars: stars ?? this.stars,
      review: review ?? this.review,
      createdAt: createdAt ?? this.createdAt,
      season: season ?? this.season,
      isVerified: isVerified ?? this.isVerified,
      teacherReply: teacherReply ?? this.teacherReply,
      teacherReplyTime: teacherReplyTime ?? this.teacherReplyTime,
    );
  }
}
