import 'package:cloud_firestore/cloud_firestore.dart';

class BlockedUserModel {
  final String blockerId;
  final String blockedId;
  final DateTime timestamp;

  BlockedUserModel({
    required this.blockerId,
    required this.blockedId,
    required this.timestamp,
  });

  factory BlockedUserModel.fromMap(Map<String, dynamic> map) {
    return BlockedUserModel(
      blockerId: map['blockerId']?.toString() ?? '',
      blockedId: map['blockedId']?.toString() ?? '',
      // Timestamp Safe Parsing
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is Timestamp 
              ? (map['timestamp'] as Timestamp).toDate() 
              : DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'blockerId': blockerId,
      'blockedId': blockedId,
      'timestamp': FieldValue.serverTimestamp(), 
    };
  }
}
