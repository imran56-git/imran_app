import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../utils/image_utils.dart'; // Standard import for your helper

class TeacherRegistrationScreen extends StatefulWidget {
  const TeacherRegistrationScreen({super.key});

  @override
  State<TeacherRegistrationScreen> createState() => _TeacherRegistrationScreenState();
}

class _TeacherRegistrationScreenState extends State<TeacherRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _qualificationController = TextEditingController();

  List<String> _selectedSubjects = [];
  String? _currentLocation;
  File? _profileImage;
  File? _qualificationCertificate;
  File? _idProofImage;
  String? _gender;
  bool _isLoading = false;
  bool _isAccepted = false;

  final String _policyUrl = "https://docs.google.com/document/d/1pLnjsGpdQwmbdytG7ZC5Nro7LHaOmgy8nSLCKGEgy0E/edit?usp=drivesdk";

  final List<String> _allSubjects = [
    'Math', 'English', 'Physics', 'Chemistry', 'Biology', 'History', 'Geography'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _qualificationController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(_policyUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $_policyUrl');
    }
  }

  Future<void> _pickImage(Function(File) onPicked) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) onPicked(File(picked.path));
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      setState(() {
        _currentLocation = '${position.latitude}, ${position.longitude}';
      });
    } catch (e) {
      _showSnackBar('Location error: $e');
    }
  }

  Future<String> _processAndUpload(File file, String path) async {
    // Compressing image before upload to save memory
    File? compressedFile = await ImageHelper.compressImage(file);
    File fileToUpload = compressedFile ?? file;

    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(fileToUpload);
    return await ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_gender == null || _profileImage == null || _selectedSubjects.isEmpty ||
        _currentLocation == null || _qualificationCertificate == null || _idProofImage == null) {
      _showSnackBar('Please fill all fields and upload all required documents');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;
      await userCredential.user!.sendEmailVerification();

      // Uploading compressed images
      final profileUrl = await _processAndUpload(_profileImage!, 'teachers/$uid/profile.jpg');
      final certUrl = await _processAndUpload(_qualificationCertificate!, 'teachers/$uid/certificate.jpg');
      final idProofUrl = await _processAndUpload(_idProofImage!, 'teachers/$uid/id_proof.jpg');

      await FirestoreService().saveTeacherData(uid, {
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'teachingLocation': _locationController.text.trim(),
        'currentLocation': _currentLocation,
        'gender': _gender,
        'subjects': _selectedSubjects,
        'qualification': _qualificationController.text.trim(),
        'profileImageUrl': profileUrl,
        'qualificationCertificateUrl': certUrl,
        'idProofUrl': idProofUrl,
        'createdAt': DateTime.now(),
        'role': 'teacher',
        'isEmailVerified': false,
        'isAcceptedTerms': _isAccepted,
      });

      _showSnackBar('Registration successful! Verify your email.', isError: false);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error: $e');
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
      appBar: AppBar(
        title: const Text('Teacher Registration', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProfileImagePicker(),
              const SizedBox(height: 20),
              _buildTextField(_nameController, 'Full Name', Icons.person),
              _buildEmailField(),
              _buildTextField(_passwordController, 'Password', Icons.lock, isObscure: true),
              _buildTextField(_phoneController, 'Phone Number', Icons.phone, inputType: TextInputType.phone),
              _buildTextField(_locationController, 'Teaching Area/Location', Icons.map),
              _buildTextField(_qualificationController, 'Educational Qualification', Icons.school),
              const SizedBox(height: 12),
              _buildLocationRow(),
              _buildGenderDropdown(),
              const SizedBox(height: 15),
              const Align(alignment: Alignment.centerLeft, child: Text('Select Subjects:', style: TextStyle(fontWeight: FontWeight.bold))),
              ..._allSubjects.map(_buildSubjectCheckbox).toList(),
              const SizedBox(height: 15),
              _buildUploadTile('Qualification Certificate', _qualificationCertificate, () => _pickImage((file) => setState(() => _qualificationCertificate = file))),
              _buildUploadTile('ID Proof (NID/Passport)', _idProofImage, () => _pickImage((file) => setState(() => _idProofImage = file))),
              const SizedBox(height: 25),
              _buildTermsCheckbox(),
              const SizedBox(height: 20),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImagePicker() {
    return GestureDetector(
      onTap: () => _pickImage((file) => setState(() => _profileImage = file)),
      child: CircleAvatar(
        radius: 55,
        backgroundColor: Colors.blue[50],
        backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
        child: _profileImage == null ? Icon(Icons.add_a_photo, size: 35, color: Colors.blue[800]) : null,
      ),
    );
  }

  Widget _buildEmailField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(labelText: 'Email Address', prefixIcon: const Icon(Icons.email), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        validator: (val) => (val == null || val.isEmpty) ? 'Email is required' : (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val) ? 'Enter a valid email' : null),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isObscure = false, TextInputType inputType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isObscure,
        keyboardType: inputType,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        validator: (val) => val == null || val.isEmpty ? '$label is required' : (isObscure && val.length < 6 ? 'Password too short' : null),
      ),
    );
  }

  Widget _buildLocationRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(_currentLocation ?? 'Detect current location', style: TextStyle(color: Colors.grey[700]))),
          IconButton(icon: const Icon(Icons.my_location, color: Colors.blue), onPressed: _fetchCurrentLocation),
        ],
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _gender,
      decoration: InputDecoration(labelText: 'Gender', prefixIcon: const Icon(Icons.people), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      items: const [DropdownMenuItem(value: 'Male', child: Text('Male')), DropdownMenuItem(value: 'Female', child: Text('Female'))],
      onChanged: (val) => setState(() => _gender = val),
    );
  }

  Widget _buildSubjectCheckbox(String subject) {
    return CheckboxListTile(
      title: Text(subject),
      value: _selectedSubjects.contains(subject),
      onChanged: (selected) => setState(() => selected! ? _selectedSubjects.add(subject) : _selectedSubjects.remove(subject)),
    );
  }

  Widget _buildUploadTile(String label, File? file, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(file != null ? 'File attached' : 'No file selected', style: TextStyle(color: file != null ? Colors.green : Colors.red, fontSize: 12)),
      trailing: IconButton(icon: const Icon(Icons.cloud_upload, color: Colors.blue), onPressed: onTap),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(value: _isAccepted, onChanged: (val) => setState(() => _isAccepted = val ?? false)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 13),
              children: [
                const TextSpan(text: "I agree to the "),
                TextSpan(
                  text: "Terms & Conditions",
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                  recognizer: TapGestureRecognizer()..onTap = _launchUrl,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: (_isLoading || !_isAccepted) ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isAccepted ? Colors.blue[800] : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('REGISTER AS TEACHER', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
