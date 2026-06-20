import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../utils/image_utils.dart';

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

  List<String> _selectedSubjects = [];
  File? _profileImage;
  File? _qualificationCertificate;
  File? _idProofImage;
  bool _isLoading = false;
  bool _isAccepted = false;
  bool _isEmailVerificationSent = false;

  final String _policyUrl = "https://docs.google.com/document/d/1pLnjsGpdQwmbdytG7ZC5Nro7LHaOmgy8nSLCKGEgy0E/edit?usp=drivesdk";

  final List<String> _allSubjects = [
    'Mathematics', 'General Science', 'Social Science', 'English', 'Bengali', 'Hindi', 'Environmental Studies', 'Computer Applications', 'History', 'Geography',
    'Physics', 'Chemistry', 'Biology', 'Economics', 'Political Science', 'Sociology', 'Philosophy', 'Psychology', 'Accountancy', 'Business Studies', 'Computer Science',
    'Statistics', 'Engineering Drawing', 'Physical Education', 'Electrician', 'Fitter', 'Welder', 'COPA', 'Electronics Mechanic', 'Civil Draftsman', 'Plumber',
    'Refrigeration & Air Conditioning', 'Turner', 'Machinist', 'Law', 'Fine Arts', 'Music', 'Nutrition', 'Home Science', 'Management', 'Mass Communication',
    'Sanskrit', 'Arabic', 'Urdu', 'French', 'German', 'Information Technology', 'Biotechnology', 'Marine Engineering', 'Agriculture', 'Horticulture', 'Geology',
    'Astronomy', 'Robotics', 'Graphic Design', 'Web Development', 'Digital Marketing', 'Fashion Technology', 'Interior Designing', 'Hotel Management', 'Tourism',
    'Event Management', 'Public Administration', 'Anthropology', 'Social Work', 'Criminology', 'Library Science', 'Data Science', 'Artificial Intelligence',
    'Cyber Security', 'Yoga', 'Vedic Mathematics', 'Spoken English', 'Calligraphy', 'Photography', 'Film Editing', 'Animation', 'Aerospace Engineering'
  ];

  Future<void> _pickImage(Function(File) onPicked) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) onPicked(File(picked.path));
  }

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(_policyUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $_policyUrl');
    }
  }

  Future<void> _sendEmailVerificationLink() async {
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await userCredential.user!.sendEmailVerification();
      setState(() => _isEmailVerificationSent = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification link sent!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<String> _processAndUpload(File file, String path) async {
    File? compressedFile = await ImageHelper.compressImage(file);
    File fileToUpload = compressedFile ?? file;
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(fileToUpload);
    return await ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profileImage == null || _qualificationCertificate == null || _idProofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload all required documents.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        final uid = user.uid;
        final profileUrl = await _processAndUpload(_profileImage!, 'teachers/$uid/profile.jpg');
        final certUrl = await _processAndUpload(_qualificationCertificate!, 'teachers/$uid/certificate.jpg');
        final idProofUrl = await _processAndUpload(_idProofImage!, 'teachers/$uid/id_proof.jpg');

        await FirebaseFirestore.instance.collection('teachers').doc(uid).set({
          'uid': uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'teachingLocation': _locationController.text.trim(),
          'subjects': _selectedSubjects,
          'profileUrl': profileUrl,
          'certUrl': certUrl,
          'idProofUrl': idProofUrl,
          'status': 'pending'
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please verify your email first.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Registration")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _pickImage((f) => setState(() => _profileImage = f)),
                        child: CircleAvatar(radius: 50, backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null, child: _profileImage == null ? const Icon(Icons.camera_alt, size: 50) : null),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(), floatingLabelBehavior: FloatingLabelBehavior.auto)),
                      const SizedBox(height: 10),
                      TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(), floatingLabelBehavior: FloatingLabelBehavior.auto)),
                      const SizedBox(height: 10),
                      if (!_isEmailVerificationSent) ElevatedButton(onPressed: _sendEmailVerificationLink, child: const Text("Send Verification Link")),
                      TextFormField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), floatingLabelBehavior: FloatingLabelBehavior.auto)),
                      const SizedBox(height: 10),
                      TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(), floatingLabelBehavior: FloatingLabelBehavior.auto)),
                      const SizedBox(height: 10),
                      TextFormField(controller: _locationController, decoration: const InputDecoration(labelText: 'Teaching Location', border: OutlineInputBorder(), floatingLabelBehavior: FloatingLabelBehavior.auto)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Select Subjects:", style: TextStyle(fontWeight: FontWeight.bold)),
                      Wrap(
                        spacing: 8,
                        children: _allSubjects.map((s) => FilterChip(
                          label: Text(s),
                          selected: _selectedSubjects.contains(s),
                          onSelected: (val) => setState(() => val ? _selectedSubjects.add(s) : _selectedSubjects.remove(s)),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                title: const Text("Upload Qualification Certificate"),
                trailing: IconButton(icon: const Icon(Icons.upload_file), onPressed: () => _pickImage((f) => setState(() => _qualificationCertificate = f))),
                subtitle: Text(_qualificationCertificate != null ? "File Selected" : "No file selected"),
              ),
              ListTile(
                title: const Text("Upload ID Proof (NID/Passport)"),
                trailing: IconButton(icon: const Icon(Icons.upload_file), onPressed: () => _pickImage((f) => setState(() => _idProofImage = f))),
                subtitle: Text(_idProofImage != null ? "File Selected" : "No file selected"),
              ),
              CheckboxListTile(
                value: _isAccepted,
                onChanged: (val) => setState(() => _isAccepted = val!),
                title: RichText(
                  text: TextSpan(children: [
                    const TextSpan(text: "I accept the ", style: TextStyle(color: Colors.black)),
                    TextSpan(text: "Terms & Conditions", style: const TextStyle(color: Colors.blue), recognizer: TapGestureRecognizer()..onTap = _launchUrl),
                  ]),
                ),
              ),
              ElevatedButton(
                onPressed: _isAccepted ? _submit : null,
                style: ElevatedButton.styleFrom(backgroundColor: _isAccepted ? Colors.blue : Colors.grey),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("REGISTER AS TEACHER"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           