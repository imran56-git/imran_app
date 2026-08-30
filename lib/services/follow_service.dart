import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/follow_model.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send or Resend Follow Request (Student to Teacher)
  Future<void> sendFollowRequest({
    required String teacherId,
    required String studentId,
    required String teacherName,
    required String studentName,
    required String teacherPhoto,
    required String studentPhoto,
  }) async {
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

      // set with merge handles both creation and update safely
      await docRef.set(followModel.toMap(), SetOptions(merge: true));
    } catch (e) {
      log('Error in sendFollowRequest: $e');
      rethrow;
    }
  }

  // Cancel Follow Request (Student side)
  Future<void> cancelRequest(String teacherId, String studentId) async {
    try {
      final String docId = '${teacherId}_$studentId';
      final docRef = _firestore.collection('follow_requests').doc(docId);

      // Using set with merge avoids crash if doc doesn't exist
      await docRef.set({
        'status': 'cancelled',
        'rejectedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      log('Error in cancelRequest: $e');
      rethrow;
    }
  }

  // Accept Follow Request (Teacher side)
  Future<void> acceptRequest(String teacherId, String studentId) async {
    try {
      final String docId = '${teacherId}_$studentId';
      final batch = _firestore.batch();

      // 1. Update follow request status
      final requestRef = _firestore.collection('follow_requests').doc(docId);
      batch.set(requestRef, {
        'status': 'accepted',
        'acceptedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      // 2. Increment teacher's count
      final teacherRef = _firestore.collection('teachers').doc(teacherId);
      batch.set(teacherRef, {
        'followersCount': FieldValue.increment(1),
        'acceptedStudentsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      log('Error in acceptRequest: $e');
      rethrow;
    }
  }

  // Reject Follow Request (Teacher side)
  Future<void> rejectRequest(String teacherId, String studentId) async {
    try {
      final String docId = '${teacherId}_$studentId';
      final docRef = _firestore.collection('follow_requests').doc(docId);

      await docRef.set({
        'status': 'rejected',
        'rejectedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      log('Error in rejectRequest: $e');
      rethrow;
    }
  }

  // Unfollow Teacher (Student side)
  Future<void> unfollowTeacher(String teacherId, String studentId) async {
    try {
      final String docId = '${teacherId}_$studentId';
      final requestRef = _firestore.collection('follow_requests').doc(docId);

      final docSnap = await requestRef.get();
      bool wasAccepted = false;
      if (docSnap.exists) {
        wasAccepted = docSnap.data()?['status'] == 'accepted';
      }

      final batch = _firestore.batch();

      // 1. Delete follow request doc if exists
      if (docSnap.exists) {
        batch.delete(requestRef);
      }

      // 2. Decrement teacher's count if it was accepted previously
      if (wasAccepted) {
        final teacherRef = _firestore.collection('teachers').doc(teacherId);
        batch.set(teacherRef, {
          'followersCount': FieldValue.increment(-1),
          'acceptedStudentsCount': FieldValue.increment(-1),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      log('Error in unfollowTeacher: $e');
      rethrow;
    }
  }

  // Stream Follow Status between specific student and teacher
  Stream<String> streamFollowStatus(String teacherId, String studentId) {
    if (teacherId.isEmpty || studentId.isEmpty) {
      return Stream.value('none');
    }
    final String docId = '${teacherId}_$studentId';
    return _firestore
        .collection('follow_requests')
        .doc(docId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return 'none';
      }
      return snapshot.data()!['status'] ?? 'none';
    });
  }

  // Realtime Followers Count Stream for Teacher Profile
  Stream<int> streamFollowersCount(String teacherId) {
    if (teacherId.isEmpty) return Stream.value(0);
    return _firestore
        .collection('follow_requests')
        .where('teacherId', isEqualTo: teacherId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Check if student is accepted by teacher
  Future<bool> isAcceptedStudent(String teacherId, String studentId) async {
    try {
      final String docId = '${teacherId}_$studentId';
      final doc = await _firestore.collection('follow_requests').doc(docId).get();
      if (!doc.exists) return false;
      return doc.data()?['status'] == 'accepted';
    } catch (e) {
      log('Error in isAcceptedStudent: $e');
      return false;
    }
  }

  // Get Pending Requests for a Teacher
  Stream<List<FollowModel>> getPendingRequests(String teacherId) {
    return _firestore
        .collection('follow_requests')
        .where('teacherId', isEqualTo: teacherId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => FollowModel.fromMap(doc.data())).toList();
    });
  }

  // Get Accepted Students for a Teacher
  Stream<List<FollowModel>> getAcceptedStudents(String teacherId) {
    return _firestore
        .collection('follow_requests')
        .where('teacherId', isEqualTo: teacherId)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => FollowModel.fromMap(doc.data())).toList();
    });
  }
}
