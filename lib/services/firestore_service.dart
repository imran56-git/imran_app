import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> searchStudentById(String searchId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(searchId).get();
      
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('uid')) {
          data['uid'] = doc.id;
        }
        return data;
      }

      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('uid', isEqualTo: searchId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data() as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      debugPrint("Error in searchStudentById: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchTeachers(Map<String, dynamic> filters) async {
    try {
      String? teacherId = filters['teacherId']?.toString().trim();
      
      if (teacherId != null && teacherId.isNotEmpty) {
        DocumentSnapshot doc = await _firestore.collection('users').doc(teacherId).get();
        if (doc.exists && doc.data() != null) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          if (data['role'] == 'teacher') {
            if (!data.containsKey('uid')) data['uid'] = doc.id;
            return [data];
          }
        }

        QuerySnapshot querySnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'teacher')
            .where('uid', isEqualTo: teacherId)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          return querySnapshot.docs.map((d) => d.data() as Map<String, dynamic>).toList();
        }
        
        return [];
      }

      Query query = _firestore.collection('users').where('role', isEqualTo: 'teacher');

      if (filters['subject'] != null && filters['subject'].toString().isNotEmpty) {
        query = query.where('subject', isEqualTo: filters['subject'].toString().trim());
      }

      if (filters['location'] != null && filters['location'].toString().isNotEmpty) {
        query = query.where('location', isEqualTo: filters['location'].toString().trim());
      }

      QuerySnapshot querySnapshot = await query.get();
      
      List<Map<String, dynamic>> results = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('uid')) {
          data['uid'] = doc.id;
        }
        return data;
      }).toList();

      if (filters['name'] != null && filters['name'].toString().isNotEmpty) {
        String searchName = filters['name'].toString().toLowerCase().trim();
        results = results.where((t) {
          String teacherName = (t['name'] ?? '').toString().toLowerCase();
          return teacherName.contains(searchName);
        }).toList();
      }

      if (filters['experience'] != null && filters['experience'].toString().isNotEmpty) {
        double minExp = double.tryParse(filters['experience'].toString()) ?? 0.0;
        results = results.where((t) {
          double exp = double.tryParse(t['experience'].toString()) ?? 0.0;
          return exp >= minExp;
        }).toList();
      }

      if (filters['maxRadius'] != null) {
        double maxR = double.tryParse(filters['maxRadius'].toString()) ?? 99999.0;
        double minR = double.tryParse(filters['minRadius']?.toString() ?? '0.0') ?? 0.0;
        results = results.where((t) {
          double dist = double.tryParse(t['distance'].toString()) ?? 0.0;
          return dist >= minR && dist <= maxR;
        }).toList();
      }

      return results;
    } catch (e) {
      debugPrint("Error in searchTeachers: $e");
      return [];
    }
  }
}
