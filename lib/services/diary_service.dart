```dart
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
    final cleanTeacherId = teacherId.trim();
    final cleanStudentId = studentId.trim();
    final String docId = '${cleanTeacherId}_${cleanStudentId}_$year';

    final batch = _firestore.batch();

    final feeDocRef = _firestore.collection('student_fees').doc(docId);
    batch.set(feeDocRef, {
      'teacherId': cleanTeacherId,
      'teacherName': teacherName.trim(),
      'studentId': cleanStudentId,
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

    final monthlyRef = _firestore.collection('monthly_fee').doc(cleanStudentId);
    batch.set(monthlyRef, {
      'studentId': cleanStudentId,
      'studentName': studentName.trim(),
      'subject': subject.trim(),
      'teacherId': cleanTeacherId,
      'pendingAmount': totalDue,
      'totalPaid': totalPaid,
      'monthlyFee': monthlyFee,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> updateMonthStatus({
    required String teacherId,
    required String studentId,
    required int year,
    required String month,
    required String newStatus,
    required double monthlyFee,
  }) async {
    final cleanTeacherId = teacherId.trim();
    final cleanStudentId = studentId.trim();
    final String docId = '${cleanTeacherId}_${cleanStudentId}_$year';

    final docRef = _firestore.collection('student_fees').doc(docId);
    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data() == null) return;

    final data = snapshot.data()!;
    final Map<String, dynamic> statuses =
        Map<String, dynamic>.from(data['monthStatuses'] ?? {});

    statuses[month] = newStatus;

    final int paidCount = statuses.values.where((s) => s == 'PAID').length;
    final int dueCount = statuses.values.where((s) => s == 'DUE').length;
    final double totalPaid = paidCount * monthlyFee;
    final double totalDue = dueCount * monthlyFee;

    final batch = _firestore.batch();

    batch.update(docRef, {
      'monthStatuses': statuses,
      'paidMonthsCount': paidCount,
      'dueMonthsCount': dueCount,
      'totalPaid': totalPaid,
      'totalDue': totalDue,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    final monthlyRef = _firestore.collection('monthly_fee').doc(cleanStudentId);
    batch.set(monthlyRef, {
      'pendingAmount': totalDue,
      'totalPaid': totalPaid,
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

  Future<DocumentSnapshot> getStudentFeeRecord(
    String teacherId,
    String studentId,
    int year,
  ) {
    final String docId = '${teacherId.trim()}_${studentId.trim()}_$year';
    return _firestore.collection('student_fees').doc(docId).get();
  }

  Future<void> deleteStudentFeeRecord(String docId, {String? studentId}) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('student_fees').doc(docId));

    if (studentId != null && studentId.trim().isNotEmpty) {
      batch.delete(_firestore.collection('monthly_fee').doc(studentId.trim()));
    }

    await batch.commit();
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

  Stream<List<DiaryModel>> getDiaryEntriesForStudent(
    String teacherId,
    String studentId,
  ) {
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
```