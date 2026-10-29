import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';

class UnregisteredGoogleAccountException implements Exception {
  final String email;
  UnregisteredGoogleAccountException(this.email);

  @override
  String toString() => 'ACCOUNT_NOT_REGISTERED:$email';
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Future<String?> resolveUserRole(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final role = userDoc.data()!['role']?.toString().trim().toLowerCase();
        if (role == 'teacher' || role == 'student') {
          await _cleanupCorruptedOppositeRoleDoc(uid, role!);
          return role;
        }
      }

      final studentDoc = await _firestore.collection('students').doc(uid).get();
      final teacherDoc = await _firestore.collection('teachers').doc(uid).get();

      final bool hasValidStudent = studentDoc.exists &&
          studentDoc.data() != null &&
          (studentDoc.data()!['name']?.toString().trim().isNotEmpty == true ||
              studentDoc.data()!['role'] == 'student');

      final bool hasValidTeacher = teacherDoc.exists &&
          teacherDoc.data() != null &&
          (teacherDoc.data()!['name']?.toString().trim().isNotEmpty == true ||
              teacherDoc.data()!['role'] == 'teacher');

      if (hasValidStudent && !hasValidTeacher) {
        await _firestore
            .collection('users')
            .doc(uid)
            .set({'role': 'student'}, SetOptions(merge: true));
        await _cleanupCorruptedOppositeRoleDoc(uid, 'student');
        return 'student';
      }

      if (hasValidTeacher && !hasValidStudent) {
        await _firestore
            .collection('users')
            .doc(uid)
            .set({'role': 'teacher'}, SetOptions(merge: true));
        await _cleanupCorruptedOppositeRoleDoc(uid, 'teacher');
        return 'teacher';
      }

      if (hasValidStudent) return 'student';
      if (hasValidTeacher) return 'teacher';

      return null;
    } catch (e) {
      log('Resolve Role Error: $e');
      return null;
    }
  }

  Future<void> _cleanupCorruptedOppositeRoleDoc(
      String uid, String actualRole) async {
    try {
      final oppositeCollection =
          (actualRole == 'student') ? 'teachers' : 'students';
      final oppositeDoc =
          await _firestore.collection(oppositeCollection).doc(uid).get();

      if (oppositeDoc.exists && oppositeDoc.data() != null) {
        final data = oppositeDoc.data()!;
        final hasName = data['name']?.toString().trim().isNotEmpty ?? false;
        final docRole = data['role']?.toString().trim().toLowerCase();

        if (!hasName && docRole != oppositeCollection.substring(0, oppositeCollection.length - 1)) {
          await _firestore.collection(oppositeCollection).doc(uid).delete();
        }
      }
    } catch (_) {}
  }

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
        final role = await resolveUserRole(credential.user!.uid);
        await _syncUserFcmToken(credential.user!.uid, role: role);
      }

      return credential;
    } catch (e) {
      log('Login Error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      final cleanRole = role.trim().toLowerCase() == 'teacher'
          ? 'teacher'
          : 'student';

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
          'name': name.trim(),
          'role': cleanRole,
          'isOnline': true,
          'status': 'Online',
          'fcmToken': token ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('users').doc(user.uid).set(userData);

        String collectionPath =
            (cleanRole == 'teacher') ? 'teachers' : 'students';
        await _firestore
            .collection(collectionPath)
            .doc(user.uid)
            .set(userData, SetOptions(merge: true));
      }

      return credential;
    } catch (e) {
      log('SignUp Error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut().catchError((_) => null);

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final String? existingRole = await resolveUserRole(user.uid);

        if (existingRole == null) {
          final String attemptedEmail = user.email ?? googleUser.email;
          try {
            if (userCredential.additionalUserInfo?.isNewUser == true) {
              await user.delete();
            }
          } catch (_) {}
          await _googleSignIn.signOut().catchError((_) => null);
          await _auth.signOut();
          throw UnregisteredGoogleAccountException(attemptedEmail);
        }

        await _syncUserFcmToken(user.uid, role: existingRole);
      }

      return userCredential;
    } catch (e) {
      log('Google Sign-In Error: $e');
      rethrow;
    }
  }

  Future<void> _syncUserFcmToken(String userId, {String? role}) async {
    try {
      String? token = await _messaging.getToken();
      final resolvedRole = role ?? await resolveUserRole(userId);
      if (resolvedRole == null) return;

      Map<String, dynamic> updateData = {
        'role': resolvedRole,
        'isOnline': true,
        'status': 'Online',
        'lastSeen': FieldValue.serverTimestamp(),
      };
      if (token != null && token.isNotEmpty) {
        updateData['fcmToken'] = token;
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .set(updateData, SetOptions(merge: true));

      final targetCollection =
          (resolvedRole == 'teacher') ? 'teachers' : 'students';
      await _firestore
          .collection(targetCollection)
          .doc(userId)
          .set(updateData, SetOptions(merge: true));
    } catch (e) {
      log('Sync Token Error: $e');
    }
  }

  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final role = await resolveUserRole(user.uid);

        Map<String, dynamic> offlineData = {
          'isOnline': false,
          'status': 'Offline',
          'lastSeen': FieldValue.serverTimestamp(),
        };

        if (role != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(offlineData, SetOptions(merge: true));

          final targetCollection =
              (role == 'teacher') ? 'teachers' : 'students';
          await _firestore
              .collection(targetCollection)
              .doc(user.uid)
              .set(offlineData, SetOptions(merge: true));
        }
      }

      await _googleSignIn.signOut().catchError((_) => null);
      await _auth.signOut();
    } catch (e) {
      log('SignOut Error: $e');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      log('Password Reset Error: $e');
      rethrow;
    }
  }
}
