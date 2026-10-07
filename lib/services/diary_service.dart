import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/diary_model.dart';

class DiaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveStudentFeeRecord({
    required String teacherId,
    required String teacherName,
    required String studentId,
    required String studentName,
    required String subject,
    required int year,
    required double monthlyFee,
    required Map<String, String> monthStatuses,
    required int paidMonthsCount,
    required int dueMonthsCount,
    required double totalPaid,
    required double totalDue,
  }) async {
    final String docId = '${teacherId.trim()}_${studentId.trim()}_$year';
    final batch = _firestore.batch();

    final feeDocRef = _firestore.collection('student_fees').doc(docId);
    batch.set(feeDocRef, {
      'teacherId': teacherId.trim(),
      'teacherName': teacherName.trim(),
      'studentId': studentId.trim(),
      'studentName': studentName.trim(),
      'subject': subject.trim(),
      'year': year,
      'monthlyFee': monthlyFee,
      'monthStatuses': monthStatuses,
      'paidMonthsCount': paidMonthsCount,
      'dueMonthsCount': dueMonthsCount,
      'totalPaid': totalPaid,
      'totalDue': totalDue,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final monthlyRef = _firestore.collection('monthly_fee').doc(studentId.trim());
    batch.set(monthlyRef, {
      'studentId': studentId.trim(),
      'studentName': studentName.trim(),
      'subject': subject.trim(),
      'teacherId': teacherId.trim(),
      'pendingAmount': totalDue,
      'totalPaid': totalPaid,
      'monthlyFee': monthlyFee,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Stream<QuerySnapshot> getStudentFeesByTeacher(String teacherId) {
    return _firestore
        .collection('student_fees')
        .where('teacherId', isEqualTo: teacherId.trim())
        .snapshots();
  }

  Future<DocumentSnapshot> getStudentFeeRecord(String teacherId, String studentId, int year) {
    final String docId = '${teacherId.trim()}_${studentId.trim()}_$year';
    return _firestore.collection('student_fees').doc(docId).get();
  }

  Future<void> deleteStudentFeeRecord(String docId) async {
    await _firestore.collection('student_fees').doc(docId).delete();
  }

  Future<void> saveDiaryEntry(DiaryModel diary) async {
    await _firestore
        .collection('teacher_diary')
        .doc(diary.diaryId)
        .set(diary.toMap());
  }

  Stream<List<DiaryModel>> getDiaryEntriesByTeacher(String teacherId) {
    return _firestore
        .collection('teacher_diary')
        .where('teacherId', isEqualTo: teacherId.trim())
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DiaryModel.fromMap(doc.data());
      }).toList();
    });
  }

  Stream<List<DiaryModel>> getDiaryEntriesForStudent(String teacherId, String studentId) {
    return _firestore
        .collection('teacher_diary')
        .where('teacherId', isEqualTo: teacherId.trim())
        .where('studentId', isEqualTo: studentId.trim())
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DiaryModel.fromMap(doc.data());
      }).toList();
    });
  }
}
