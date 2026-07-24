import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/badge_model.dart';
import 'badge_evaluator_service.dart';

class VerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BadgeEvaluatorService _badgeEvaluator = BadgeEvaluatorService();

  /// ১. শিক্ষক ভেরিফিকেশনের জন্য রিকোয়েস্ট সাবমিট করবেন
  Future<void> submitVerificationRequest({
    required String teacherId,
    required String teacherName,
    required String documentType, // e.g., 'NID', 'Certificate', 'Institutional ID'
    required String documentUrl,
    String? note,
  }) async {
    final docRef = _firestore.collection('verification_requests').doc(teacherId);

    await docRef.set({
      'teacherId': teacherId,
      'teacherName': teacherName,
      'documentType': documentType,
      'documentUrl': documentUrl,
      'note': note ?? '',
      'status': 'pending', // 'pending', 'approved', 'rejected'
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // শিক্ষকের মেইন ডকুমেন্টেও ভেরিফিকেশন পেন্ডিং স্ট্যাটাস আপডেট করা
    await _firestore.collection('teachers').doc(teacherId).update({
      'verificationStatus': 'pending',
    });
  }

  /// ২. এডমিন প্যানেলের জন্য: সকল পেন্ডিং ভেরিফিকেশন রিকোয়েস্ট ফেচ করা
  Future<List<Map<String, dynamic>>> getPendingVerificationRequests() async {
    final querySnapshot = await _firestore
        .collection('verification_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .get();

    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  /// ৩. এডমিন ভেরিফিকেশন Approve করবেন
  Future<void> approveTeacherVerification({
    required String teacherId,
    required String adminId,
  }) async {
    final batch = _firestore.batch();

    // Verification Request Document আপডেট
    final requestRef = _firestore.collection('verification_requests').doc(teacherId);
    batch.update(requestRef, {
      'status': 'approved',
      'reviewedBy': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Teacher Profile-এ ভেরিফাইড ফ্ল্যাগ আপডেট
    final teacherRef = _firestore.collection('teachers').doc(teacherId);
    batch.update(teacherRef, {
      'isVerified': true,
      'verificationStatus': 'approved',
      'verifiedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // ভেরিফাইড হওয়ার পর টিচারের ব্যাজ আপডেট রি-ইভালুয়েট করা
    final badge = BadgeModel(
      id: 'badge_verified_$teacherId',
      teacherId: teacherId,
      type: BadgeType.verified,
      title: 'Verified Teacher',
      description: 'Identity and credentials verified by admin.',
      unlockedAt: DateTime.now(),
    );

    await _badgeEvaluator.assignVerifiedBadge(teacherId: teacherId, badge: badge);
  }

  /// ৪. এডমিন ভেরিফিকেশন Reject করবেন
  Future<void> rejectTeacherVerification({
    required String teacherId,
    required String adminId,
    required String rejectionReason,
  }) async {
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
  }

  /// ৫. কোনো নির্দিষ্ট শিক্ষকের ভেরিফিকেশন স্ট্যাটাস দেখা
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamVerificationStatus(String teacherId) {
    return _firestore.collection('verification_requests').doc(teacherId).snapshots();
  }
}
