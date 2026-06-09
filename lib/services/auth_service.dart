import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  Future<void> sendPasswordReset(String email) async {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        }
        }