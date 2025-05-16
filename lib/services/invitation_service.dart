import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invitation_model.dart';

class InvitationService {
  final CollectionReference _invites =
      FirebaseFirestore.instance.collection('groupInvitations');

  Future<void> sendInvitation({
    required String groupId,
    required String groupName,
    required String invitedUserId,
    required String invitedByUserId,
  }) async {
    final newInvite = InvitationModel(
      id: '',
      groupId: groupId,
      groupName: groupName,
      invitedUserId: invitedUserId,
      invitedByUserId: invitedByUserId,
      status: 'pending',
      timestamp: DateTime.now(),
    );

    await _invites.add(newInvite.toMap());
  }
}
