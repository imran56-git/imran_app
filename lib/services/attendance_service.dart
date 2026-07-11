import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveAttendance(AttendanceModel attendance) async {
    final String docId = "${attendance.teacherId}_${attendance.studentId}_${attendance.date.year}${attendance.date.month}${attendance.date.day}";
    await _firestore
        .collection('attendance')
        .doc(docId)
        .set(attendance.toMap());
  }

  Stream<List<AttendanceModel>> getAttendanceByDate(String teacherId, DateTime date) {
    final DateTime startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection('attendance')
        .where('teacherId', isEqualTo: teacherId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return AttendanceModel.fromMap(doc.data());
      }).toList();
    });
  }

  Stream<List<AttendanceModel>> getStudentAttendanceHistory(String teacherId, String studentId) {
    return _firestore
        .collection('attendance')
        .where('teacherId', isEqualTo: teacherId)
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return AttendanceModel.fromMap(doc.data());
      }).toList();
    });
  }
}
