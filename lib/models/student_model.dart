import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class StudentModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String photoUrl;
  final String location;
  final String bio;
  final List<String> interestedSubjects;
  final String studentClass;
  final Timestamp createdAt;

  // Rating & Verification system fields
  final List<String> ratedTeachers;
  final List<String> verifiedTeacherIds;

  const StudentModel({
    required this.id,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.location,
    required this.bio,
    required this.interestedSubjects,
    required this.studentClass,
    required this.createdAt,
    this.ratedTeachers = const [],
    this.verifiedTeacherIds = const [],
  });

  factory StudentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return StudentModel(
      id: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      location: map['location'] ?? '',
      bio: map['bio'] ?? '',
      interestedSubjects: List<String>.from(map['interestedSubjects'] ?? []),
      studentClass: map['studentClass'] ?? '',
      createdAt: map['createdAt'] is Timestamp 
          ? map['createdAt'] as Timestamp 
          : Timestamp.now(),
      // Rating & Verification mappings
      ratedTeachers: List<String>.from(map['ratedTeachers'] ?? []),
      verifiedTeacherIds: List<String>.from(map['verifiedTeacherIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'location': location,
      'bio': bio,
      'interestedSubjects': interestedSubjects,
      'studentClass': studentClass,
      'createdAt': createdAt,
      // Rating & Verification fields
      'ratedTeachers': ratedTeachers,
      'verifiedTeacherIds': verifiedTeacherIds,
    };
  }

  StudentModel copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    String? location,
    String? bio,
    List<String>? interestedSubjects,
    String? studentClass,
    Timestamp? createdAt,
    List<String>? ratedTeachers,
    List<String>? verifiedTeacherIds,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      interestedSubjects: interestedSubjects ?? this.interestedSubjects,
      studentClass: studentClass ?? this.studentClass,
      createdAt: createdAt ?? this.createdAt,
      ratedTeachers: ratedTeachers ?? this.ratedTeachers,
      verifiedTeacherIds: verifiedTeacherIds ?? this.verifiedTeacherIds,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        photoUrl,
        location,
        bio,
        interestedSubjects,
        studentClass,
        createdAt,
        ratedTeachers,
        verifiedTeacherIds,
      ];
}
