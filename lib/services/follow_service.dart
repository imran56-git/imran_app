import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/follow_model.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sendFollowRequest({
    required String teacherId,
    required String studentId,
    required String teacherName,
    required String studentName,
    required String teacherPhoto,
    required String studentPhoto,
    List<String> subjects = const [],
  }) async {
    if (teacherId.isEmpty || studentId.isEmpty) return;

    try {
      final String docId = '${teacherId}_$studentId';
      final docRef = _firestore.collection('follow_requests').doc(docId);

      final followModel = FollowModel(
        id: docId,
        teacherId: teacherId,
        studentId: studentId,
        teacherName: teacherName,
        studentName: studentName,
        teacherPhoto: teacherPhoto,
        studentPhoto: studentPhoto,
        status: 'pending',
        requestedAt: Timestamp.now(),
        subjects: subjects,
      );

      final batch = _firestore.batch();
      batch.set(docRef, followModel.toMap(), SetOptions(merge: true));

      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'notificationId': notifRef.id,
        'receiverId': teacherId,
        'senderId': studentId,
        'senderName': studentName,
        'senderPhoto': studentPhoto,
        'type': 'follow_request',
        'title': 'New Follow Request',
        'body': '$studentName sent you a follow request.',
        'message': '$studentName sent you a follow request.',
        'isRead': false,
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'targetId': docId,
      });

      await batch.commit();
    } catch (e) {
      log('🔴 Error in sendFollowRequest: $e');
      rethrow;
    }
  }

  Future<void> cancelRequest(String teacherId, String studentId) async {
    if (teacherId.isEmpty || studentId.isEmpty) return;

    try {
      final String docId = '${teacherId}_$studentId';
      await _firestore.collection('follow_requests').doc(docId).delete();
    } catch (e) {
      log('🔴 Error in cancelRequest: $e');
      rethrow;
    }
  }

  Future<void> acceptRequest(String teacherId, String studentId) async {
    if (teacherId.isEmpty || studentId.isEmpty) return;

    try {
      final String docId = '${teacherId}_$studentId';
      final requestRef = _firestore.collection('follow_requests').doc(docId);
      final docSnap = await requestRef.get();
      final data = docSnap.data() ?? {};

      final String teacherName = (data['teacherName'] ?? 'Teacher').toString();
      final String teacherPhoto = (data['teacherPhoto'] ?? '').toString();

      final batch = _firestore.batch();

      batch.set(requestRef, {
        'status': 'accepted',
        'acceptedAt': Timestamp.now(),
        'hasVerifiedLearningExperience': true,
      }, SetOptions(merge: true));

      final teacherRef = _firestore.collection('teachers').doc(teacherId);
      batch.set(teacherRef, {
        'followersCount': FieldValue.increment(1),
        'acceptedStudentsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'notificationId': notifRef.id,
        'receiverId': studentId,
        'senderId': teacherId,
        'senderName': teacherName,
        'senderPhoto': teacherPhoto,
        'type': 'follow_accepted',
        'title': 'Follow Request Accepted',
        'body': '$teacherName accepted your follow request.',
        'message': '$teacherName accepted your follow request.',
        'isRead': false,
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'targetId': docId,
      });

      await batch.commit();
    } catch (e) {
      log('🔴 Error in acceptRequest: $e');
      rethrow;
    }
  }

  Future<void> rejectRequest(String teacherId, String studentId) async {
    if (teacherId.isEmpty || studentId.isEmpty) return;

    try {
      final String docId = '${teacherId}_$studentId';
      final docRef = _firestore.collection('follow_requests').doc(docId);
      final docSnap = await docRef.get();
      final data = docSnap.data() ?? {};
      final String teacherName = (data['teacherName'] ?? 'Teacher').toString();
      final String teacherPhoto = (data['teacherPhoto'] ?? '').toString();

      final batch = _firestore.batch();
      batch.set(docRef, {
        'status': 'rejected',
        'rejectedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'notificationId': notifRef.id,
        'receiverId': studentId,
        'senderId': teacherId,
        'senderName': teacherName,
        'senderPhoto': teacherPhoto,
        'type': 'follow_rejected',
        'title': 'Follow Request Declined',
        'body': '$teacherName declined your follow request.',
        'message': '$teacherName declined your follow request.',
        'isRead': false,
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'targetId': docId,
      });

      await batch.commit();
    } catch (e) {
      log('🔴 Error in rejectRequest: $e');
      rethrow;
    }
  }

  Future<void> unfollowTeacher(String teacherId, String studentId, {String? customUnfollowerId}) async {
    if (teacherId.isEmpty || studentId.isEmpty) return;

    try {
      final String docId = '${teacherId}_$studentId';
      final requestRef = _firestore.collection('follow_requests').doc(docId);

      final docSnap = await requestRef.get();
      bool wasAccepted = false;
      Map<String, dynamic> data = {};
      if (docSnap.exists) {
        data = docSnap.data() ?? {};
        wasAccepted = data['status'] == 'accepted';
      }

      final String currentUid = customUnfollowerId ?? (_auth.currentUser?.uid ?? '');
      final bool isTeacherInitiated = currentUid == teacherId;

      final String receiverId = isTeacherInitiated ? studentId : teacherId;
      final String senderId = isTeacherInitiated ? teacherId : studentId;
      final String senderName = isTeacherInitiated
          ? (data['teacherName'] ?? 'Teacher').toString()
          : (data['studentName'] ?? 'Student').toString();
      final String senderPhoto = isTeacherInitiated
          ? (data['teacherPhoto'] ?? '').toString()
          : (data['studentPhoto'] ?? '').toString();

      final batch = _firestore.batch();

      if (docSnap.exists) {
        batch.delete(requestRef);
      }

      if (wasAccepted) {
        final teacherRef = _firestore.collection('teachers').doc(teacherId);
        batch.set(teacherRef, {
          'followersCount': FieldValue.increment(-1),
          'acceptedStudentsCount': FieldValue.increment(-1),
        }, SetOptions(merge: true));
      }

      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'notificationId': notifRef.id,
        'receiverId': receiverId,
        'senderId': senderId,
        'senderName': senderName,
        'senderPhoto': senderPhoto,
        'type': 'unfollow',
        'title': 'Unfollowed',
        'body': '$senderName has unfollowed you.',
        'message': '$senderName has unfollowed you.',
        'isRead': false,
        'status': 'unread',
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'targetId': docId,
      });

      await batch.commit();
    } catch (e) {
      log('🔴 Error in unfollowTeacher: $e');
      rethrow;
    }
  }

  Stream<String> streamFollowStatus(String teacherId, String studentId) {
    if (teacherId.isEmpty || studentId.isEmpty) {
      return Stream.value('none');
    }
    final String docId = '${teacherId}_$studentId';
    return _firestore
        .collection('follow_requests')
        .doc(docId)
        .snapshots()
        .map<String>((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return 'none';
      }
      return snapshot.data()!['status'] ?? 'none';
    }).handleError((error) {
      log('🔴 Error streaming follow status: $error');
    }).cast<String>();
  }

  Stream<int> streamFollowersCount(String teacherId) {
    if (teacherId.isEmpty) return Stream.value(0);
    return _firestore
        .collection('follow_requests')
        .where('teacherId', isEqualTo: teacherId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map<int>((snapshot) => snapshot.docs.length)
        .handleError((error) {
      log('🔴 Error streaming followers count: $error');
    }).cast<int>();
  }

  Future<bool> isAcceptedStudent(String teacherId, String studentId) async {
    if (teacherId.isEmpty || studentId.isEmpty) return false;
    try {
      final String docId = '${teacherId}_$studentId';
      final doc = await _firestore.collection('follow_requests').doc(docId).get();
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;
      final followModel = FollowModel.fromMap(data, doc.id);
      return followModel.isEligibleToRate;
    } catch (e) {
      log('🔴 Error in isAcceptedStudent: $e');
      return false;
    }
  }

  Future<FollowModel?> getFollowConnection(String teacherId, String studentId) async {
    if (teacherId.isEmpty || studentId.isEmpty) return null;
    try {
      final String docId = '${teacherId}_$studentId';
      final doc = await _firestore.collection('follow_requests').doc(docId).get();
      if (!doc.exists || doc.data() == null) return null;
      return FollowModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      log('🔴 Error in getFollowConnection: $e');
      return null;
    }
  }

  Stream<List<FollowModel>> getPendingRequests(String teacherId) {
    if (teacherId.isEmpty) return Stream.value([]);

    return _firestore
        .collection('follow_requests')
        .where('teacherId', isEqualTo: teacherId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map<List<FollowModel>>((snapshot) {
      final List<FollowModel> list = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          list.add(FollowModel.fromMap(data, doc.id));
        } catch (e) {
          log('🔴 Parsing Error in getPendingRequests for doc ${doc.id}: $e');
        }
      }
      return list;
    }).handleError((error) {
      log('🔴 Stream Error in getPendingRequests: $error');
    }).cast<List<FollowModel>>();
  }

  Stream<List<FollowModel>> getAcceptedStudents(String teacherId) {
    if (teacherId.isEmpty) return Stream.value([]);

    return _firestore
        .collection('follow_requests')
        .where('teacherId', isEqualTo: teacherId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map<List<FollowModel>>((snapshot) {
      final List<FollowModel> list = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          list.add(FollowModel.fromMap(data, doc.id));
        } catch (e) {
          log('🔴 Parsing Error in getAcceptedStudents for doc ${doc.id}: $e');
        }
      }
      return list;
    }).handleError((error) {
      log('🔴 Stream Error in getAcceptedStudents: $error');
    }).cast<List<FollowModel>>();
  }
}
