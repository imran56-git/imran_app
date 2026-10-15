import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/algorithm_config.dart';

class FollowModel {
  final String id;
  final String teacherId;
  final String studentId;
  final String teacherName;
  final String studentName;
  final String teacherPhoto;
  final String studentPhoto;
  final String status;
  final Timestamp? requestedAt;
  final Timestamp? acceptedAt;
  final Timestamp? rejectedAt;
  final bool isActiveTuitionStudent;
  final bool hasVerifiedLearningExperience;
  final List<String> subjects;
  final String? lastRatedSeasonId;
  final String? lastPromptedSeasonId;

  FollowModel({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.teacherName,
    required this.studentName,
    required this.teacherPhoto,
    required this.studentPhoto,
    required this.status,
    this.requestedAt,
    this.acceptedAt,
    this.rejectedAt,
    this.isActiveTuitionStudent = false,
    this.hasVerifiedLearningExperience = false,
    this.subjects = const [],
    this.lastRatedSeasonId,
    this.lastPromptedSeasonId,
  });

  bool get isAccepted => status.toLowerCase() == 'accepted';

  bool get isEligibleToRate {
    if (!AlgorithmConfig.requireAcceptedConnectionForRating) {
      return true;
    }
    return isAccepted && acceptedAt != null;
  }

  bool canRateInSeason(String seasonId) {
    if (!isEligibleToRate) {
      return false;
    }
    if (AlgorithmConfig.allowRatingUpdatesWithinSeason) {
      return true;
    }
    return lastRatedSeasonId != seasonId;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'studentId': studentId,
      'teacherName': teacherName,
      'studentName': studentName,
      'teacherPhoto': teacherPhoto,
      'studentPhoto': studentPhoto,
      'status': status,
      'requestedAt': requestedAt ?? FieldValue.serverTimestamp(),
      'acceptedAt': acceptedAt,
      'rejectedAt': rejectedAt,
      'isActiveTuitionStudent': isActiveTuitionStudent,
      'hasVerifiedLearningExperience': hasVerifiedLearningExperience,
      'subjects': subjects,
      'lastRatedSeasonId': lastRatedSeasonId,
      'lastPromptedSeasonId': lastPromptedSeasonId,
    };
  }

  factory FollowModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return FollowModel.fromMap(map, doc.id);
  }

  factory FollowModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final parsedStatus = map['status'] ?? 'pending';
    final parsedAcceptedAt = map['acceptedAt'] as Timestamp?;
    final parsedRequestedAt = map['requestedAt'] as Timestamp?;

    return FollowModel(
      id: (docId != null && docId.isNotEmpty) ? docId : (map['id'] ?? ''),
      teacherId: map['teacherId'] ?? '',
      studentId: map['studentId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      studentName: map['studentName'] ?? '',
      teacherPhoto: map['teacherPhoto'] ?? '',
      studentPhoto: map['studentPhoto'] ?? '',
      status: parsedStatus,
      requestedAt: parsedRequestedAt,
      acceptedAt: parsedAcceptedAt ??
          (parsedStatus == 'accepted' ? parsedRequestedAt : null),
      rejectedAt: map['rejectedAt'] as Timestamp?,
      isActiveTuitionStudent: map['isActiveTuitionStudent'] ?? false,
      hasVerifiedLearningExperience:
          map['hasVerifiedLearningExperience'] ?? false,
      subjects: List<String>.from(map['subjects'] as List? ?? []),
      lastRatedSeasonId: map['lastRatedSeasonId'],
      lastPromptedSeasonId: map['lastPromptedSeasonId'],
    );
  }

  FollowModel copyWith({
    String? id,
    String? teacherId,
    String? studentId,
    String? teacherName,
    String? studentName,
    String? teacherPhoto,
    String? studentPhoto,
    String? status,
    Timestamp? requestedAt,
    Timestamp? acceptedAt,
    Timestamp? rejectedAt,
    bool? isActiveTuitionStudent,
    bool? hasVerifiedLearningExperience,
    List<String>? subjects,
    String? lastRatedSeasonId,
    String? lastPromptedSeasonId,
  }) {
    return FollowModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      studentId: studentId ?? this.studentId,
      teacherName: teacherName ?? this.teacherName,
      studentName: studentName ?? this.studentName,
      teacherPhoto: teacherPhoto ?? this.teacherPhoto,
      studentPhoto: studentPhoto ?? this.studentPhoto,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      isActiveTuitionStudent:
          isActiveTuitionStudent ?? this.isActiveTuitionStudent,
      hasVerifiedLearningExperience:
          hasVerifiedLearningExperience ?? this.hasVerifiedLearningExperience,
      subjects: subjects ?? this.subjects,
      lastRatedSeasonId: lastRatedSeasonId ?? this.lastRatedSeasonId,
      lastPromptedSeasonId: lastPromptedSeasonId ?? this.lastPromptedSeasonId,
    );
  }
}
