import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/live_class_model.dart';

class LiveClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<LiveClassModel?> watchLiveClass(String roomId) {
    return _firestore
        .collection('live_classes')
        .doc(roomId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return LiveClassModel.fromMap(snapshot.data()!);
    });
  }

  Future<void> createLiveClass(LiveClassModel liveClass) async {
    await _firestore
        .collection('live_classes')
        .doc(liveClass.roomId)
        .set(liveClass.toMap());
  }

  Future<void> endLiveClass(String roomId) async {
    await _firestore.collection('live_classes').doc(roomId).update({
      'isLive': false,
    });
  }

  Future<void> updateMediaStatus(String roomId, {required bool isMicMuted, required bool isCameraOff}) async {
    await _firestore.collection('live_classes').doc(roomId).update({
      'isMicMuted': isMicMuted,
      'isCameraOff': isCameraOff,
    });
  }

  Future<void> toggleHandRaise(String roomId, String userId, bool raise) async {
    await _firestore.collection('live_classes').doc(roomId).update({
      'handRaisedUsers': raise 
          ? FieldValue.arrayUnion([userId]) 
          : FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> toggleUserMicPermission(String roomId, String userId, bool allow) async {
    await _firestore.collection('live_classes').doc(roomId).update({
      'allowedMicUsers': allow 
          ? FieldValue.arrayUnion([userId]) 
          : FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> joinParticipant(String roomId, String userId) async {
    await _firestore.collection('live_classes').doc(roomId).update({
      'participants': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> leaveParticipant(String roomId, String userId) async {
    await _firestore.collection('live_classes').doc(roomId).update({
      'participants': FieldValue.arrayRemove([userId]),
      'handRaisedUsers': FieldValue.arrayRemove([userId]),
      'allowedMicUsers': FieldValue.arrayRemove([userId]),
    });
  }
}
