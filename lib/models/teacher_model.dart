import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherModel {
  final String id;
    final String name;
      final bool isOnline;
        final DateTime lastSeen;
          final bool isTyping;
            final bool isVerified;
              final bool hasSpecialBadge;

                TeacherModel({
                    required this.id,
                        required this.name,
                            required this.isOnline,
                                required this.lastSeen,
                                    required this.isTyping,
                                        required this.isVerified,
                                            required this.hasSpecialBadge,
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
                                                                                                  );
                                                                                                    }

                                                                                                      Map<String, dynamic> toMap() {
                                                                                                          return {
                                                                                                                'name': name,
                                                                                                                      'isOnline': isOnline,
                                                                                                                            'lastSeen': lastSeen,
                                                                                                                                  'isTyping': isTyping,
                                                                                                                                        'isVerified': isVerified,
                                                                                                                                              'hasSpecialBadge': hasSpecialBadge,
                                                                                                                                                  };
                                                                                                                                                    }
                                                                                                                                                    }