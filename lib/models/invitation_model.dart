class InvitationModel {
  final String id;
  final String groupId;
  final String groupName;
  final String invitedUserId;
  final String invitedByUserId;
  final String status; // pending, accepted, rejected
  final DateTime timestamp;

  InvitationModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.invitedUserId,
    required this.invitedByUserId,
    required this.status,
    required this.timestamp,
  });

  factory InvitationModel.fromMap(String id, Map<String, dynamic> map) {
    return InvitationModel(
      id: id,
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] ?? '',
      invitedUserId: map['invitedUserId'] ?? '',
      invitedByUserId: map['invitedByUserId'] ?? '',
      status: map['status'] ?? 'pending',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'invitedUserId': invitedUserId,
      'invitedByUserId': invitedByUserId,
      'status': status,
      'timestamp': timestamp,
    };
  }
}
