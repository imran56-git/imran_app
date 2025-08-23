class TeacherModel {
  final String id;
  final String name;
  final bool isOnline;
  final DateTime lastSeen;
  final bool isTyping;

  TeacherModel({
    required this.id,
    required this.name,
    required this.isOnline,
    required this.lastSeen,
    required this.isTyping,
  });

  factory TeacherModel.fromMap(Map<String, dynamic> map, String docId) {
    return TeacherModel(
      id: docId,
      name: map['name'] ?? '',
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen']?.toDate() ?? DateTime.now(),
      isTyping: map['isTyping'] ?? false,
    );
  }

  // Firestore-এ ডেটা সংরক্ষণের জন্য
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'isTyping': isTyping,
    };
  }
}