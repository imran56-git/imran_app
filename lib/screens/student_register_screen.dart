import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/image_utils.dart';

class StudentRegistrationScreen extends StatefulWidget {
  const StudentRegistrationScreen({super.key});

  @override
  State<StudentRegistrationScreen> createState() => _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _homeLocationController = TextEditingController();

  File? _profileImage;
  String? _gender;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isAccepted = false;

  final String _policyUrl = "https://docs.google.com/document/d/1pLnjsGpdQwmbdytG7ZC5Nro7LHaOmgy8nSLCKGEgy0E/edit?usp=drivesdk";

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _homeLocationController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(_policyUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $_policyUrl');
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) setState(() => _profileImage = File(pickedFile.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_profileImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a profile photo')),
      );
      return;
    }

    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select gender')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim());

      await userCredential.user!.sendEmailVerification();

      final String uid = userCredential.user!.uid;
      String imageUrl = "";
      
      File? compressedFile = await ImageHelper.compressImage(_profileImage!);
      final ref = FirebaseStorage.instance.ref().child('student_profiles/$uid.jpg');
      await ref.putFile(compressedFile ?? _profileImage!);
      imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('students').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'homeLocation': _homeLocationController.text.trim(),
        'gender': _gender,
        'profileImageUrl': imageUrl,
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(
          context: context, 
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Verify Your Email"),
            content: const Text("A verification link has been sent to your email. Please check your inbox and verify to login."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                }, 
                child: const Text("OK")
              )
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool isPass = false, TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        obscureText: isPass ? !_isPasswordVisible : false,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: isPass ? IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
        validator: (val) {
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
      appBar: AppBar(title: const Text("Student Registration")),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: CircleAvatar(
                                radius: 50, 
                                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null, 
                                child: _profileImage == null ? const Icon(Icons.camera_alt, size: 40) : null
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildField(_nameController, "Full Name", Icons.person),
                            _buildField(_emailController, "Email Address", Icons.email, type: TextInputType.emailAddress),
                            _buildField(_passwordController, "Password", Icons.lock, isPass: true),
                            _buildField(_phoneController, "Phone Number", Icons.phone, type: TextInputType.phone),
                            _buildField(_homeLocationController, "Home Area", Icons.home),
                            DropdownButtonFormField<String>(
                              value: _gender,
                              decoration: InputDecoration(
                                labelText: 'Gender', 
                                prefixIcon: const Icon(Icons.people), 
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
                              ),
                              items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                              onChanged: (v) => setState(() => _gender = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _isAccepted,
                          onChanged: (v) => setState(() => _isAccepted = v!),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black), 
                              children: [
                                const TextSpan(text: "I agree to "),
                                TextSpan(
                                  text: "Terms & Conditions", 
                                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold), 
                                  recognizer: TapGestureRecognizer()..onTap = _launchUrl
                                ),
                              ]
                            ),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _isAccepted ? _submit : null,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      child: const Text("REGISTER"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
