import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart'; // সেশন ট্র্যাকিংয়ের জন্য যুক্ত করা হয়েছে

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

  // SharedPreferences-এ সেশন ও রোল সেভ করার প্রফেশনাল মেথড
  Future<void> _saveUserSession(String uid, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', uid);
    await prefs.setString('userType', role);
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
      // ওল্ড সেশন ক্লিয়ার করে ফ্রেশ সাইন-ইন নিশ্চিত করা
      await _googleSignIn.signOut();
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
    // ১. প্রথমে টিচার কালেকশন চেক করা হচ্ছে (Clean Architecture)
    DocumentSnapshot teacherDoc = await _firestore.collection('teachers').doc(user.uid).get();

    String userType = 'student';

    if (teacherDoc.exists) {
      userType = 'teacher';
    } else {
      // ২. টিচার না হলে স্টুডেন্ট কালেকশন চেক করা
      DocumentSnapshot studentDoc = await _firestore.collection('students').doc(user.uid).get();
      if (studentDoc.exists) {
        userType = 'student';
      } else {
        // যদি কোনো কালেকশনেই ডেটা না থাকে (নতুন গুগল সাইন-ইন ইউজার)
        userType = 'student'; // ডিফল্ট রোল স্টুডেন্ট

        // "No Name" বাগ ফিক্স: গুগলের নাম অথবা ইমেলের প্রথম অংশ ব্যাকআপ হিসেবে নেওয়া হলো
        String finalName = user.displayName ?? user.email!.split('@')[0];

        await _firestore.collection('students').doc(user.uid).set({
          'uid': user.uid,
          'name': finalName, // 'name' ফিল্ড নিশ্চিত করা হলো
          'email': user.email,
          'userType': 'student',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // SharedPreferences সেশন স্টোর করা হলো
    await _saveUserSession(user.uid, userType);

    if (!mounted) return;

    // Navigation Stack সম্পূর্ণ ক্লিন করে হোম স্ক্রিনে রিডাইরেক্ট
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => userType == 'teacher'
            // বাগ ফিক্স: TeacherHomeScreen-এ রিকোয়ার্ড প্যারামিটার 'currentUserId' পাস করা হলো
            ? TeacherHomeScreen(currentUserId: user.uid)
            : StudentHomeScreen(currentUserId: user.uid),
      ),
      (route) => false,
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.school_rounded,
                  size: 90,
                  color: Color(0xFF128C7E),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Welcome Back",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                // ইমেল ইনপুট
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // পাসওয়ার্ড ইনপুট
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  validator: (val) => val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
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
                      style: TextStyle(color: Color(0xFF128C7E), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF128C7E))
                    : Column(
                        children: [
                          // লগইন বাটন
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF128C7E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          const Row(
                            children: [
                              Expanded(child: Divider(thickness: 1)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text("OR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(child: Divider(thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 25),

                          // গুগল লগইন বাটন
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: OutlinedButton.icon(
                              onPressed: _handleGoogleSignIn,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.grey),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.g_mobiledata_rounded,
                                size: 35,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'Continue with Google',
                                // বাগ ফিক্স: Colors.blackDE এর জায়গায় স্ট্যান্ডার্ড Colors.black87 ব্যবহার করা হলো
                                style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
                              ),
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
