import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

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
        await _syncUserFcmToken(credential.user!.uid);
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

        await _firestore.collection('users').doc(user.uid).set(userData);

        String collectionPath = (role == 'teacher') ? 'teachers' : 'students';
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

  Future<UserCredential?> signInWithGoogle({String defaultRole = 'student'}) async {
    try {
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
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        String? token = await _messaging.getToken();

        if (!userDoc.exists) {
          Map<String, dynamic> newUserData = {
            'uid': user.uid,
            'email': user.email ?? '',
            'name': user.displayName ?? 'User',
            'role': defaultRole,
            'photoUrl': user.photoURL ?? '',
            'isOnline': true,
            'status': 'Online',
            'fcmToken': token ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
          };

          await _firestore.collection('users').doc(user.uid).set(newUserData);

          String collectionPath =
              (defaultRole == 'teacher') ? 'teachers' : 'students';
          await _firestore
              .collection(collectionPath)
              .doc(user.uid)
              .set(newUserData, SetOptions(merge: true));
        } else {
          await _syncUserFcmToken(user.uid);
        }
      }

      return userCredential;
    } catch (e) {
      log('Google Sign-In Error: $e');
      rethrow;
    }
  }

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

      await _firestore
          .collection('users')
          .doc(userId)
          .set(updateData, SetOptions(merge: true));

      await _firestore
          .collection('teachers')
          .doc(userId)
          .set(updateData, SetOptions(merge: true));

      await _firestore
          .collection('students')
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
        Map<String, dynamic> offlineData = {
          'isOnline': false,
          'status': 'Offline',
          'lastSeen': FieldValue.serverTimestamp(),
        };

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(offlineData, SetOptions(merge: true));

        await _firestore
            .collection('teachers')
            .doc(user.uid)
            .set(offlineData, SetOptions(merge: true));

        await _firestore
            .collection('students')
            .doc(user.uid)
            .set(offlineData, SetOptions(merge: true));
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
