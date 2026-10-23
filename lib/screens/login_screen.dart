import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '575213013835-6vmhuc5tc13il0fla1ifru2d3a0o7ups.apps.googleusercontent.com',
    scopes: <String>['email', 'profile'],
  );

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveUserSession(String uid, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', uid);
    await prefs.setString('userType', role);
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user ?? _auth.currentUser;
      if (user != null) {
        await _checkAndNavigateUser(user);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-email':
          errorMessage = 'No account found with this email.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        default:
          errorMessage = e.message ?? 'Login failed. Please check credentials.';
      }
      _showError(errorMessage);
    } catch (e) {
      _showError('Login failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      await _googleSignIn.signOut().catchError((_) => null);
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        _showError('Google Sign-In failed: idToken and accessToken are both null.');
        return;
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        await _checkAndNavigateUser(user);
      }
    } on FirebaseAuthException catch (e) {
      _showError('Firebase Auth Error [${e.code}]: ${e.message}');
    } on PlatformException catch (e) {
      _showError('Google Platform Error [${e.code}]: ${e.message}');
    } catch (e) {
      _showError('Google Sign-In Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkAndNavigateUser(User user) async {
    String userType = 'student';

    try {
      final DocumentSnapshot teacherDoc = await _firestore
          .collection('teachers')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));

      if (teacherDoc.exists) {
        userType = 'teacher';
      } else {
        final DocumentSnapshot studentDoc = await _firestore
            .collection('students')
            .doc(user.uid)
            .get(const GetOptions(source: Source.serverAndCache));

        if (studentDoc.exists) {
          userType = 'student';
        } else {
          final DocumentSnapshot userDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get(const GetOptions(source: Source.serverAndCache));

          if (userDoc.exists && userDoc.data() != null) {
            final uData = userDoc.data() as Map<String, dynamic>;
            final String role = (uData['role'] ?? uData['userType'] ?? 'student')
                .toString()
                .toLowerCase();
            userType = role == 'teacher' ? 'teacher' : 'student';
          } else {
            userType = 'student';
            final String finalName =
                user.displayName ?? (user.email?.split('@')[0] ?? 'Student');

            await _firestore.collection('students').doc(user.uid).set({
              'uid': user.uid,
              'name': finalName,
              'fullName': finalName,
              'email': user.email ?? '',
              'userType': 'student',
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            await _firestore.collection('users').doc(user.uid).set({
              'uid': user.uid,
              'name': finalName,
              'email': user.email ?? '',
              'role': 'student',
              'userType': 'student',
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      }
    } catch (_) {
      userType = 'student';
    }

    await _saveUserSession(user.uid, userType);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => userType == 'teacher'
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
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Widget _buildOfficialGoogleLogo() {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
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
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(val.trim())) {
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
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  validator: (val) => val == null || val.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
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
                      style: TextStyle(
                          color: Color(0xFF128C7E),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF128C7E))
                    : Column(
                        children: [
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
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          const Row(
                            children: [
                              Expanded(child: Divider(thickness: 1)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text("OR",
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold)),
                              ),
                              Expanded(child: Divider(thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 25),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: OutlinedButton.icon(
                              onPressed: _handleGoogleSignIn,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: _buildOfficialGoogleLogo(),
                              label: const Text(
                                'Continue with Google',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold),
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

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double strokeWidth = w * 0.22;
    final Rect arcRect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      w - strokeWidth,
      h - strokeWidth,
    );

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(arcRect, -2.35, 1.55, false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(arcRect, 2.35, 1.58, false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(arcRect, 0.75, 1.60, false, paint);

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(arcRect, -0.15, 0.90, false, paint);

    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        w * 0.50,
        h * 0.41,
        w * 0.46,
        strokeWidth * 0.92,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
