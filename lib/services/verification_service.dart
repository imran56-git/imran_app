import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/badge_model.dart';
import '../models/rating_summary_model.dart';
import 'badge_service.dart';

class VerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BadgeService _badgeService = BadgeService();

  Future<void> submitVerificationRequest({
    required String teacherId,
    required String teacherName,
    required String documentType,
    required String documentUrl,
    String? note,
  }) async {
    try {
      final docRef = _firestore.collection('verification_requests').doc(teacherId);

      await docRef.set({
        'teacherId': teacherId,
        'teacherName': teacherName,
        'documentType': documentType,
        'documentUrl': documentUrl,
        'note': note ?? '',
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('teachers').doc(teacherId).update({
        'verificationStatus': 'pending',
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingVerificationRequests() async {
    try {
      final querySnapshot = await _firestore
          .collection('verification_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> approveTeacherVerification({
    required String teacherId,
    required String adminId,
  }) async {
    try {
      final batch = _firestore.batch();

      final requestRef = _firestore.collection('verification_requests').doc(teacherId);
      batch.update(requestRef, {
        'status': 'approved',
        'reviewedBy': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final teacherRef = _firestore.collection('teachers').doc(teacherId);
      batch.update(teacherRef, {
        'isVerified': true,
        'verificationStatus': 'approved',
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      final teacherDoc = await teacherRef.get();
      final teacherData = teacherDoc.data() ?? {};
      final ratingSummary = RatingSummaryModel.fromMap(
        teacherData['ratingSummary'] as Map<String, dynamic>? ?? {},
        teacherId,
      );

      await _badgeService.evaluateAndAssignBadges(
        teacherId: teacherId,
        isAdminApproved: true,
        documentsApproved: true,
        ratingSummary: ratingSummary,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectTeacherVerification({
    required String teacherId,
    required String adminId,
    required String rejectionReason,
  }) async {
    try {
      final batch = _firestore.batch();

      final requestRef = _firestore.collection('verification_requests').doc(teacherId);
      batch.update(requestRef, {
        'status': 'rejected',
        'rejectionReason': rejectionReason,
        'reviewedBy': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final teacherRef = _firestore.collection('teachers').doc(teacherId);
      batch.update(teacherRef, {
        'isVerified': false,
        'verificationStatus': 'rejected',
      });

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamVerificationStatus(String teacherId) {
    return _firestore.collection('verification_requests').doc(teacherId).snapshots();
  }
}
