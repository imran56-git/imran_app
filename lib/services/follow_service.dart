import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/follow_model.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send Follow Request (Student to Teacher)
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

      await docRef.set(followModel.toMap());
    } catch (e) {
      log('Error in sendFollowRequest: $e');
      throw Exception('Failed to send follow request: $e');
    }
  }

  // Cancel Follow Request (Student side)
  Future<void> cancelRequest(String teacherId, String studentId) async {
    try {
      final String docId = '${teacherId}_$studentId';
      await _firestore.collection('follow_requests').doc(docId).update({
        'status': 'cancelled',
        'rejectedAt': Timestamp.now(),
      });
    } catch (e) {
      log('Error in cancelRequest: $e');
    }
  }

  // Accept Follow Request (Teacher side)
  Future<void> acceptRequest(String teacherId, String studentId) async {
    try {
      final String docId = '${teacherId}_$studentId';
      final batch = _firestore.batch();

      // 1. Update follow request status
      final requestRef = _firestore.collection('follow_requests').doc(docId);
      batch.update(requestRef, {
        'status': 'accepted',
        'acceptedAt': Timestamp.now(),
      });

      // 2. Increment teacher's acceptedStudentsCount
      final teacherRef = _firestore.collection('teachers').doc(teacherId);
      batch.update(teacherRef, {
        'acceptedStudentsCount': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (e) {
      log('Error in acceptRequest: $e');
      throw Exception('Failed to accept request: $e');
    }
  }

  // Reject Follow Request (Teacher side)
  Future<void> rejectRequest(String teacherId, String studentId) async {
    try {
      final String docId = '${teacherId}_$studentId';
      await _firestore.collection('follow_requests').doc(docId).update({
        'status': 'rejected',
        'rejectedAt': Timestamp.now(),
      });
    } catch (e) {
      log('Error in rejectRequest: $e');
    }
  }

  // Unfollow Teacher (Student side)
  Future<void> unfollowTeacher(String teacherId, String studentId) async {
    try {
      final String docId = '${teacherId}_$studentId';
      final batch = _firestore.batch();

      // 1. Delete or update status to cancelled
      final requestRef = _firestore.collection('follow_requests').doc(docId);
      batch.delete(requestRef);

      // 2. Decrement teacher's acceptedStudentsCount
      final teacherRef = _firestore.collection('teachers').doc(teacherId);
      batch.update(teacherRef, {
        'acceptedStudentsCount': FieldValue.increment(-1),
      });

      await batch.commit();
    } catch (e) {
      log('Error in unfollowTeacher: $e');
    }
  }

  // Stream Follow Status between specific student and teacher
  Stream<String> streamFollowStatus(String teacherId, String studentId) {
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

  // Check if student is accepted by teacher (for Rating & Review permission)
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
