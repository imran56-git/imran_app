import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/diary_model.dart';

class DiaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveDiaryEntry(DiaryModel diary) async {
    await _firestore
        .collection('teacher_diary')
        .doc(diary.diaryId)
        .set(diary.toMap());
  }

  Stream<List<DiaryModel>> getDiaryEntriesByTeacher(String teacherId) {
    return _firestore
        .collection('teacher_diary')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('date', descending: true)
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
        .where('teacherId', isEqualTo: teacherId)
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DiaryModel.fromMap(doc.data());
      }).toList();
    });
  }
}
