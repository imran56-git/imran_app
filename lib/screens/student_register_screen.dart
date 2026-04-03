import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/image_utils.dart'; // Standard helper for compression

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
  String? _fetchedLocation; 
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
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _fetchedLocation = "Fetching...");
    // Integration point for your actual location service
    await Future.delayed(const Duration(seconds: 1)); 
    setState(() => _fetchedLocation = "Detected Location Area"); 
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profileImage == null) {
      _showSnackBar('Please upload a profile photo');
      return;
    }
    if (_gender == null) {
      _showSnackBar('Please select your gender');
      return;
    }
    if (!_isAccepted) return;

    setState(() => _isLoading = true);

    try {
      // 1. Create User Authentication
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim());

      final String uid = userCredential.user!.uid;

      // 2. Image Compression & Upload
      String imageUrl = "";
      File? compressedFile = await ImageHelper.compressImage(_profileImage!);
      
      final ref = FirebaseStorage.instance.ref().child('student_profiles/$uid.jpg');
      await ref.putFile(compressedFile ?? _profileImage!);
      imageUrl = await ref.getDownloadURL();

      // 3. Save Student Data to Firestore
      await FirebaseFirestore.instance.collection('students').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'homeLocation': _homeLocationController.text.trim(),
        'currentLocation': _fetchedLocation ?? "Not specified",
        'gender': _gender,
        'profileImageUrl': imageUrl,
        'userType': 'student',
        'isAcceptedTerms': _isAccepted,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnackBar('Registration Successful!', isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Student Registration", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildImagePicker(),
                  const SizedBox(height: 30),
                  _buildTextField(_nameController, "Full Name", Icons.person),
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildTextField(_phoneController, "Phone Number", Icons.phone, type: TextInputType.phone),
                  _buildPasswordField(),
                  const SizedBox(height: 16),
                  _buildTextField(_homeLocationController, "Home Area", Icons.home),
                  _buildLocationRow(),
                  const SizedBox(height: 16),
                  _buildGenderDropdown(),
                  const SizedBox(height: 30),
                  _buildTermsAndConditions(),
                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Row(
      children: [
        Checkbox(
          value: _isAccepted,
          activeColor: Colors.blue[800],
          onChanged: (val) => setState(() => _isAccepted = val ?? false),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 13),
              children: [
                const TextSpan(text: "I agree to the "),
                TextSpan(
                  text: "Terms & Conditions and Privacy Policy",
                  style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                  recognizer: TapGestureRecognizer()..onTap = _launchUrl,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blue[50],
              backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
              child: _profileImage == null ? Icon(Icons.add_a_photo, size: 40, color: Colors.blue[800]) : null,
            ),
            Positioned(bottom: 0, right: 4, child: CircleAvatar(backgroundColor: Colors.blue[800], radius: 18, child: const Icon(Icons.edit, color: Colors.white, size: 18))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: "Email Address", 
        prefixIcon: const Icon(Icons.email), 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
      ),
      validator: (val) {
        if (val == null || val.isEmpty) return "Email is required";
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) return "Enter a valid email address";
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextFormField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        decoration: InputDecoration(
          labelText: "Create Password",
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off), 
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (val) => val!.length < 6 ? "Minimum 6 characters needed" : null,
      ),
    );
  }

  Widget _buildLocationRow() {
    return Row(
      children: [
        Expanded(child: Text(_fetchedLocation ?? "Location not detected", style: TextStyle(color: Colors.grey[700]))),
        TextButton.icon(
          onPressed: _getCurrentLocation, 
          icon: const Icon(Icons.my_location), 
          label: const Text("Get Location")
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _gender,
      decoration: InputDecoration(
        labelText: 'Gender', 
        prefixIcon: const Icon(Icons.people), 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
      ),
      items: const [
        DropdownMenuItem(value: 'Male', child: Text('Male')), 
        DropdownMenuItem(value: 'Female', child: Text('Female'))
      ],
      onChanged: (value) => setState(() => _gender = value),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isAccepted ? _submit : null,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: _isAccepted ? Colors.blue[800] : Colors.grey,
          foregroundColor: Colors.white,
        ),
        child: const Text("REGISTER NOW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label, 
          prefixIcon: Icon(icon), 
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
        ),
        validator: (val) => val!.isEmpty ? "$label is required" : null,
      ),
    );
  }
}
