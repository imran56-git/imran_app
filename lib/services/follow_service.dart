import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/follow_model.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendFollowRequest({
    required String teacherId,
    required String studentId,
    required String teacherName,
    required String studentName,
    required String teacherPhoto,
    required String studentPhoto,
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
      );

      await docRef.set(followModel.toMap(), SetOptions(merge: true));
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
      final batch = _firestore.batch();

      final requestRef = _firestore.collection('follow_requests').doc(docId);
      batch.set(requestRef, {
        'status': 'accepted',
        'acceptedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      final teacherRef = _firestore.collection('teachers').doc(teacherId);
      batch.set(teacherRef, {
        'followersCount': FieldValue.increment(1),
        'acceptedStudentsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

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

      await docRef.set({
        'status': 'rejected',
        'rejectedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      log('🔴 Error in rejectRequest: $e');
      rethrow;
    }
  }

  Future<void> unfollowTeacher(String teacherId, String studentId) async {
    if (teacherId.isEmpty || studentId.isEmpty) return;

    try {
      final String docId = '${teacherId}_$studentId';
      final requestRef = _firestore.collection('follow_requests').doc(docId);

      final docSnap = await requestRef.get();
      bool wasAccepted = false;
      if (docSnap.exists) {
        wasAccepted = docSnap.data()?['status'] == 'accepted';
      }

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
      return doc.data()?['status'] == 'accepted';
    } catch (e) {
      log('🔴 Error in isAcceptedStudent: $e');
      return false;
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
          data['id'] = doc.id;
          list.add(FollowModel.fromMap(data));
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
          data['id'] = doc.id;
          list.add(FollowModel.fromMap(data));
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
