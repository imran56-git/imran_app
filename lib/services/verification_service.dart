import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/badge_model.dart';
import 'badge_service.dart'; // ✅ আসল ফাইলের নাম অনুযায়ী ইম্পোর্ট করা হলো

class VerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BadgeService _badgeService = BadgeService(); // ✅ BadgeService ব্যবহার করা হয়েছে

  /// ১. শিক্ষক ভেরিফিকেশনের জন্য রিকোয়েস্ট সাবমিট করবেন
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

  /// ২. এডমিন প্যানেলের জন্য: সকল পেন্ডিং ভেরিফিকেশন রিকোয়েস্ট ফেচ করা
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

  /// ৩. এডমিন ভেরিফিকেশন Approve করবেন
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

      // ভেরিফাইড হওয়ার পর ব্যাজ অ্যাসাইন করা
      final badge = BadgeModel(
        id: 'badge_verified_$teacherId',
        teacherId: teacherId,
        type: BadgeType.verified,
        description: 'Identity and credentials verified by admin.',
        unlockedAt: DateTime.now(),
      );

      // আপনার BadgeService-এর মেথড অনুযায়ী কল করুন
      await _badgeService.assignBadge(teacherId, badge);
    } catch (e) {
      rethrow;
    }
  }

  /// ৪. এডমিন ভেরিফিকেশন Reject করবেন
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

  /// ৫. কোনো নির্দিষ্ট শিক্ষকের ভেরিফিকেশন স্ট্যাটাস দেখা
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamVerificationStatus(String teacherId) {
    return _firestore.collection('verification_requests').doc(teacherId).snapshots();
  }
}
