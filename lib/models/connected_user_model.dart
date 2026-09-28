class ConnectedUserModel {
  final String uid;
  final String name;
  final String tuitionName;
  final String? photoUrl;
  final String role;

  ConnectedUserModel({
    required this.uid,
    required this.name,
    required this.tuitionName,
    this.photoUrl,
    required this.role,
  });

  factory ConnectedUserModel.fromFirestore(Map<String, dynamic> data, String docId, String userRole) {
    String fetchedName = data['name'] ?? data['displayName'] ?? 'User';
    
    String rawTuition = data['tuitionName'] ?? data['tuition_name'] ?? data['institution'] ?? '';
    String cleanTuition = rawTuition.trim().isEmpty ? 'Tuition not specified' : rawTuition.trim();

    String? image = data['photoUrl'] ?? data['profilePic'] ?? data['imageUrl'];

    return ConnectedUserModel(
      uid: docId,
      name: fetchedName,
      tuitionName: cleanTuition,
      photoUrl: image,
      role: userRole,
    );
  }
}
