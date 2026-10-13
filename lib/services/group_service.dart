import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/invitation_model.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createGroup({
    required String name,
    required String createdBy,
    required String imageUrl,
    required String teacherName,
  }) async {
    final docRef = _firestore.collection('groups').doc();
    final group = GroupModel(
      id: docRef.id,
      name: name,
      createdBy: createdBy,
      imageUrl: imageUrl,
      members: [createdBy],
      createdAt: Timestamp.now(),
    );

    await docRef.set(group.toMap());
    return docRef.id;
  }

  Future<void> sendInvitation({
    required String groupId,
    required String groupName,
    required String invitedUserId,
    required String invitedByUserId,
  }) async {
    final docRef = _firestore.collection('invitations').doc();
    final invitation = InvitationModel(
      id: docRef.id,
      groupId: groupId,
      groupName: groupName,
      invitedUserId: invitedUserId,
      invitedByUserId: invitedByUserId,
      status: 'pending',
      timestamp: DateTime.now(),
    );

    await docRef.set(invitation.toMap());
  }

  Future<void> respondToInvitation(String invitationId, String groupId, String userId, bool accept) async {
    final status = accept ? 'accepted' : 'rejected';
    
    await _firestore.collection('invitations').doc(invitationId).update({
      'status': status,
    });

    if (accept) {
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([userId]),
      });
    }
  }

  Stream<List<GroupModel>> getTeacherGroups(String teacherId) {
    return _firestore
        .collection('groups')
        .where('createdBy', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<InvitationModel>> getStudentInvitations(String userId) {
    return _firestore
        .collection('invitations')
        .where('invitedUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InvitationModel.fromMap(doc.id, doc.data()))
            .toList());
  }
}
