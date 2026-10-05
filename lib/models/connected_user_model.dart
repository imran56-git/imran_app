class ConnectedUserModel {
  final String uid;
  final String name;
  final String? tuitionName;
  final String? photoUrl;
  final String role;

  ConnectedUserModel({
    required this.uid,
    required this.name,
    this.tuitionName,
    this.photoUrl,
    required this.role,
  });

  String? get profileImageUrl => photoUrl;
  String? get subtitle => tuitionName;

  factory ConnectedUserModel.fromFirestore(
    Map<String, dynamic> data,
    String docId,
    String userRole,
  ) {
    final fetchedName = (data['name'] ?? data['displayName'] ?? 'User').toString();

    final rawTuition = data['tuitionName'] ?? 
        data['tuition_name'] ?? 
        data['coachingName'] ?? 
        data['batchName'] ?? 
        data['institution'];

    String? displayTuition;
    if (rawTuition != null && rawTuition.toString().trim().isNotEmpty) {
      displayTuition = rawTuition.toString().trim();
    }

    final image = data['photoUrl'] ??
        data['profilePic'] ??
        data['imageUrl'] ??
        data['profileImageUrl'];

    return ConnectedUserModel(
      uid: docId,
      name: fetchedName,
      tuitionName: displayTuition,
      photoUrl: image?.toString(),
      role: userRole,
    );
  }
}
