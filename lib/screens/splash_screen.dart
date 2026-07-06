import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'forgot_passwaord_screen.dart';
import 'student_home_screen.dart';
import 'teacher_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = _auth.currentUser;
      if (user != null) {
        await _checkAndNavigateUser(user);
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Login failed');
    } catch (e) {
      _showError('Login failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _googleSignIn.signOut(); // safe fresh login
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _checkAndNavigateUser(user, isGoogleUser: true);
      }
    } catch (e) {
      _showError('Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAndNavigateUser(
    User user, {
    bool isGoogleUser = false,
  }) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    if (!mounted) return;

    if (userDoc.exists) {
      final data = userDoc.data() ?? {};
      final userType =
          (data['userType'] ?? data['role'] ?? 'student')
              .toString()
              .toLowerCase();

      _goToHome(user.uid, userType);
      return;
    }

    // New user fallback document
    await userRef.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'name': user.displayName ?? '',
      'photoUrl': user.photoURL ?? '',
      'userType': 'student',
      'role': 'student',
      'createdAt': FieldValue.serverTimestamp(),
      'provider': isGoogleUser ? 'google' : 'email',
    });

    if (!mounted) return;
    _goToHome(user.uid, 'student');
  }

  void _goToHome(String uid, String userType) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => userType == 'teacher'
            ? const TeacherHomeScreen()
            : StudentHomeScreen(currentUserId: uid),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Icon(
                  Icons.school_rounded,
                  size: 90,
                  color: Color(0xFF128C7E),
                ),
                const Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) =>
                      val == null || val.trim().isEmpty
                          ? 'Enter email'
                          : null,
                  decoration: _inputDecoration(
                    'Email Address',
                    Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  validator: (val) =>
                      val == null || val.length < 6
                          ? 'Password too short'
                          : null,
                  decoration: _inputDecoration(
                    'Password',
                    Icons.lock_outline,
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ForgotPasswordScreen(),
                      ),
                    ),
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(color: Color(0xFF12BC7E)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                _isLoading
                    ? const CircularProgressIndicator()
                    : Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _loginUser,
                              child: const Text(
                                'Login',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 10),
                                child: Text("OR"),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 25),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: OutlinedButton.icon(
                              onPressed: _handleGoogleSignIn,
                              icon: const Icon(
                                Icons.g_mobiledata_rounded,
                                size: 30,
                                color: Colors.red,
                              ),
                              label:
                                  const Text('Continue with Google'),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}