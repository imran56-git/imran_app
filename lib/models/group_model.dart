import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String createdBy;
  final String imageUrl;
  final List<String> members;
  final Timestamp createdAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.imageUrl,
    required this.members,
    required this.createdAt,
  });

  factory GroupModel.fromMap(Map<String, dynamic> data, String docId) {
    return GroupModel(
      id: docId,
      name: data['name'] ?? '',
      createdBy: data['createdBy'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'imageUrl': imageUrl,
      'members': members,
      'createdAt': createdAt,
    };
  }
}