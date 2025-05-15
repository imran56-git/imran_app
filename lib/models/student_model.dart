import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String name;
  final String email;
  final String photoUrl;
  final String location;
  final String bio;
  final List<String> interestedSubjects;
  final String studentClass;
  final Timestamp createdAt;

  StudentModel({
    required this.id,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.location,
    required this.bio,
    required this.interestedSubjects,
    required this.studentClass,
    required this.createdAt,
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
      createdAt: map['createdAt'] ?? Timestamp.now(),
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
    };
  }
}