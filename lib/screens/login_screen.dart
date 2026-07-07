import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'student_home_screen.dart';
import 'teacher_home_screen.dart';
import 'forgot_passwaord_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final _formKey = GlobalKey<FormState>();
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _checkAndNavigateUser(user);
      }
    } catch (e) {
      _showError('Google sign-in failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkAndNavigateUser(User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!mounted) return;

    if (userDoc.exists) {
      final data = userDoc.data() ?? {};
      final userType = (data['userType'] ?? data['role'] ?? 'student').toString();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => userType == 'teacher'
              ? const TeacherHomeScreen()
              : StudentHomeScreen(currentUserId: user.uid),
        ),
      );
      return;
    }

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'userType': 'student',
      'role': 'student',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StudentHomeScreen(currentUserId: user.uid),
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
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter email' : null,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  validator: (val) => val == null || val.length < 6 ? 'Password too short' : null,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
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
                                padding: EdgeInsets.symmetric(horizontal: 10),
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
                              label: const Text('Continue with Google'),
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