import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> searchTeachers({
    String? subject,
    String? location,
    String? className,
  }) async {
    try {
      Query query = _firestore.collection('teachers');

      if (subject != null && subject.isNotEmpty) {
        query = query.where('subjects', arrayContains: subject);
      }

      final querySnapshot = await query.get();

      List<Map<String, dynamic>> teachers = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      if (location != null && location.isNotEmpty) {
        teachers = teachers.where((t) {
          final loc = (t['location'] ?? '').toString().toLowerCase();
          return loc.contains(location.toLowerCase());
        }).toList();
      }

      return teachers;
    } catch (e) {
      return [];
    }
  }
}
