import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // বর্তমান ইউজার
  User? get currentUser => _auth.currentUser;

  // 🔴 ১. ইমেইল ও পাসওয়ার্ড দিয়ে সাইন-ইন (নতুন ফোনে সিঙ্ক ফিক্স সহ)
  Future<UserCredential?> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // সাইন-ইন সফল হলে সাথে সাথেই ২য়/নতুন ফোনের FCM Token সিঙ্ক করা
        await _syncUserFcmToken(credential.user!.uid);
      }

      return credential;
    } catch (e) {
      log('🔴 Login Error: $e');
      rethrow;
    }
  }

  // 🔴 ২. নতুন ইউজার রেজিস্ট্রেশন
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String role, // 'teacher' or 'student'
  }) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        String? token = await _messaging.getToken();

        Map<String, dynamic> userData = {
          'uid': user.uid,
          'email': email,
          'name': name,
          'role': role,
          'isOnline': true,
          'status': 'Online',
          'fcmToken': token ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        };

        // মূল users কালেকশনে সেভ
        await _firestore.collection('users').doc(user.uid).set(userData);

        // টিচার বা স্টুডেন্টের নির্দিষ্ট কালেকশনেও সেভ করা
        String collectionPath = (role == 'teacher') ? 'teachers' : 'students';
        await _firestore.collection(collectionPath).doc(user.uid).set(userData, SetOptions(merge: true));
      }

      return credential;
    } catch (e) {
      log('🔴 SignUp Error: $e');
      rethrow;
    }
  }

  // 🔴 ৩. ডিভাইস টোকেন (FCM Token) সিঙ্ক করার মেথড
  Future<void> _syncUserFcmToken(String userId) async {
    try {
      String? token = await _messaging.getToken();
      if (token == null) return;

      Map<String, dynamic> updateData = {
        'fcmToken': token,
        'isOnline': true,
        'status': 'Online',
        'lastSeen': FieldValue.serverTimestamp(),
      };

      // ১. 'users' কালেকশন আপডেট
      await _firestore.collection('users').doc(userId).update(updateData).catchError((_) {});

      // ২. 'teachers' বা 'students' কালেকশন আপডেট
      await _firestore.collection('teachers').doc(userId).update(updateData).catchError((_) {});
      await _firestore.collection('students').doc(userId).update(updateData).catchError((_) {});
    } catch (e) {
      log('🔴 Sync Token Error: $e');
    }
  }

  // 🔴 ৪. লগআউট (নতুন আইডি লগইনের সুবিধার্থে টোকেন ক্লিয়ার করে দেওয়া)
  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // অফলাইন করা এবং টোকেন রিসেট করা
        Map<String, dynamic> offlineData = {
          'isOnline': false,
          'status': 'Offline',
          'lastSeen': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('users').doc(user.uid).update(offlineData).catchError((_) {});
        await _firestore.collection('teachers').doc(user.uid).update(offlineData).catchError((_) {});
        await _firestore.collection('students').doc(user.uid).update(offlineData).catchError((_) {});
      }

      await _auth.signOut();
    } catch (e) {
      log('🔴 SignOut Error: $e');
    }
  }

  // ৫. পাসওয়ার্ড রিসেট ইমেইল
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      log('🔴 Password Reset Error: $e');
      rethrow;
    }
  }
}
