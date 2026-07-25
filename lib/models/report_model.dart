import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String reporterId;
  final String reportedUserId;
  final String reason;
  final DateTime timestamp;

  ReportModel({
    required this.reporterId,
    required this.reportedUserId,
    required this.reason,
    required this.timestamp,
  });

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      reporterId: map['reporterId']?.toString() ?? '',
      reportedUserId: map['reportedUserId']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
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
      'reporterId': reporterId,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
