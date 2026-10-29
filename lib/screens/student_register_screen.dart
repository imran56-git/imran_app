import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../utils/image_utils.dart';

class StudentRegistrationScreen extends StatefulWidget {
  const StudentRegistrationScreen({super.key});

  @override
  State<StudentRegistrationScreen> createState() =>
      _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _homeLocationController = TextEditingController();
  final _classController = TextEditingController();
  final _schoolController = TextEditingController();
  final _collegeController = TextEditingController();

  File? _profileImage;
  String? _gender;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isAccepted = false;

  final String _policyUrl =
      "https://docs.google.com/document/d/1pLnjsGpdQwmbdytG7ZC5Nro7LHaOmgy8nSLCKGEgy0E/edit?usp=drivesdk";

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _homeLocationController.dispose();
    _classController.dispose();
    _schoolController.dispose();
    _collegeController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(_policyUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $_policyUrl');
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final position = await LocationService.getCurrentLocation();
      _homeLocationController.text =
          "${position.latitude}, ${position.longitude}";
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Location error: $e"),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select gender'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user == null) throw Exception("User creation failed.");

      await user.sendEmailVerification();
      await user.updateDisplayName(_nameController.text.trim());

      final String uid = user.uid;
      String imageUrl = "";

      if (_profileImage != null) {
        File? compressedFile =
            await ImageHelper.compressImage(_profileImage!);
        final ref =
            FirebaseStorage.instance.ref().child("student_profiles/$uid.jpg");
        await ref.putFile(compressedFile ?? _profileImage!);
        imageUrl = await ref.getDownloadURL();
        await user.updatePhotoURL(imageUrl);
      }

      final String fullName = _nameController.text.trim();
      final String email = _emailController.text.trim();
      final String phone = _phoneController.text.trim();
      final String homeLocation = _homeLocationController.text.trim();
      final String studentClass = _classController.text.trim();
      final String schoolName = _schoolController.text.trim();
      final String collegeName = _collegeController.text.trim();

      final Map<String, dynamic> studentData = {
        'uid': uid,
        'fybttUid': uid,
        'name': fullName,
        'fullName': fullName,
        'displayName': fullName,
        'email': email,
        'phone': phone,
        'homeLocation': homeLocation,
        'address': homeLocation,
        'gender': _gender,
        'class': studentClass,
        'className': studentClass,
        'studentClass': studentClass,
        'schoolName': schoolName,
        'collegeName': collegeName,
        'institutionName': schoolName.isNotEmpty ? schoolName : collegeName,
        'profileImageUrl': imageUrl,
        'profilePic': imageUrl,
        'photoUrl': imageUrl,
        'role': 'student',
        'userType': 'student',
        'isOnline': false,
        'status': 'Offline',
        'fcmToken': '',
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('students')
          .doc(uid)
          .set(studentData, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(studentData, SetOptions(merge: true));

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Verify Your Email"),
            content: const Text(
              "A verification link has been sent to your email. Please check your inbox and verify to login.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text(
                  "OK",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "";
      switch (e.code) {
        case "email-already-in-use":
          message = "This email is already registered.";
          break;
        case "invalid-email":
          message = "Invalid email address.";
          break;
        case "weak-password":
          message = "Password must be at least 6 characters.";
          break;
        case "network-request-failed":
          message = "No internet connection.";
          break;
        case "user-disabled":
          message = "This account has been disabled.";
          break;
        case "too-many-requests":
          message = "Too many requests. Please try again later.";
          break;
        default:
          message = e.message ?? e.code;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Firebase Error: ${e.message}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unknown Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPass = false,
    TextInputType type = TextInputType.text,
    bool isLocation = false,
    bool isOptional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isPass ? !_isPasswordVisible : false,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: isOptional ? "$label (Optional)" : label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.teal.shade600, size: 22),
          suffixIcon: isPass
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(
                    () => _isPasswordVisible = !_isPasswordVisible,
                  ),
                )
              : isLocation
                  ? IconButton(
                      icon: Icon(Icons.my_location, color: Colors.teal.shade600),
                      onPressed: _getCurrentLocation,
                    )
                  : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        validator: (val) {
          if (isOptional || isLocation) return null;
          if (val == null || val.trim().isEmpty) {
            return "$label is required";
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          "Student Registration",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.teal.shade600),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: _pickImage,
                                child: CircleAvatar(
                                  radius: 54,
                                  backgroundColor: Colors.teal.shade50,
                                  backgroundImage: _profileImage != null
                                      ? FileImage(_profileImage!)
                                      : null,
                                  child: _profileImage == null
                                      ? Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.teal.shade400,
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade600,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildField(
                            _nameController,
                            "Full Name",
                            Icons.person_outline,
                          ),
                          _buildField(
                            _emailController,
                            "Email Address",
                            Icons.email_outlined,
                            type: TextInputType.emailAddress,
                          ),
                          _buildField(
                            _passwordController,
                            "Password",
                            Icons.lock_outline,
                            isPass: true,
                          ),
                          _buildField(
                            _phoneController,
                            "Phone Number",
                            Icons.phone_outlined,
                            type: TextInputType.phone,
                          ),
                          _buildField(
                            _homeLocationController,
                            "Home Area",
                            Icons.location_on_outlined,
                            isLocation: true,
                          ),
                          _buildField(
                            _classController,
                            "Class",
                            Icons.book_outlined,
                            isOptional: true,
                          ),
                          _buildField(
                            _schoolController,
                            "School Name",
                            Icons.school_outlined,
                            isOptional: true,
                          ),
                          _buildField(
                            _collegeController,
                            "College Name",
                            Icons.account_balance_outlined,
                            isOptional: true,
                          ),
                          DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: InputDecoration(
                              labelText: 'Gender',
                              labelStyle: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.people_outline,
                                color: Colors.teal.shade600,
                                size: 22,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: Colors.teal.shade600,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: ['Male', 'Female']
                                .map((g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(g),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _gender = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: _isAccepted,
                          activeColor: Colors.teal.shade600,
                          onChanged: (v) => setState(() => _isAccepted = v!),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                              children: [
                                const TextSpan(text: "I agree to "),
                                TextSpan(
                                  text: "Terms & Conditions",
                                  style: TextStyle(
                                    color: Colors.teal.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = _launchUrl,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isAccepted ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        backgroundColor: _isAccepted
                            ? Colors.teal.shade600
                            : Colors.grey.shade300,
                        elevation: _isAccepted ? 4 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "REGISTER",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
