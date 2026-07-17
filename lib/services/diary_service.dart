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
    final cleanTeacherId = teacherId.trim();
    
    return _firestore
        .collection('teacher_diary')
        .where('teacherId', isEqualTo: cleanTeacherId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DiaryModel.fromMap(doc.data());
      }).toList();
    });
  }

  /// স্টুডেন্ট ডায়েরি সার্চের ফিক্সড মেথড
  Stream<List<DiaryModel>> getDiaryEntriesForStudent(String teacherId, String studentId) {
    final cleanTeacherId = teacherId.trim();
    final cleanStudentId = studentId.trim();

    // টিপস: ফায়ারবেস কনসোলে এই কুয়েরিটির জন্য Composite Index ক্রিয়েট করা আছে কিনা নিশ্চিত হয়ে নাও।
    // যদি ইনডেক্স না থাকে, তবে কোড রান করলে কনসোলে একটি লিঙ্ক আসবে, সেখানে ক্লিক করলেই ইনডেক্স তৈরি হয়ে যাবে।
    return _firestore
        .collection('teacher_diary')
        .where('teacherId', isEqualTo: cleanTeacherId)
        .where('studentId', isEqualTo: cleanStudentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        // যদি মডেলের ভেতর কোনো কারণে আইডি মিসিং থাকে, সেটারও ব্যাকআপ হ্যান্ডেল করবে
        final data = doc.data();
        return DiaryModel.fromMap(data);
      }).toList();
    });
  }
}
