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
  final _usernameController = TextEditingController();

  List<String> _selectedSubjects = [];
  File? _profileImage;
  File? _qualificationCertificate;
  File? _idProofImage;
  bool _isLoading = false;
  bool _isAccepted = false;

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

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

  Future<void> _getCurrentLocation() async {
  setState(() => _isLoading = true);

  try {
    final position = await LocationService.getCurrentLocation();

    _locationController.text =
        "${position.latitude}, ${position.longitude}";

  } catch (e) {

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Location error: $e"),
      ),
    );

  } finally {

    setState(() => _isLoading = false);

  }
}
 
Future<bool> _checkUserIdExists(String userId) async {

  final result = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();

  return result.exists;
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
 
final userId = _usernameController.text.trim();

final exists = await _checkUserIdExists(userId);

if (exists) {

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("User ID already exists"),
      backgroundColor: Colors.red,
    ),
  );

  return;
}

    if (_profileImage == null || _qualificationCertificate == null || _idProofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all required documents.')),
      );
      return;
    }

    if (_selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one subject.')),
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

      final profileUrl = await _processAndUpload(_profileImage!, 'teachers/$uid/profile.jpg');
      final certUrl = await _processAndUpload(_qualificationCertificate!, 'teachers/$uid/certificate.jpg');
      final idProofUrl = await _processAndUpload(_idProofImage!, 'teachers/$uid/id_proof.jpg');

      await FirebaseFirestore.instance.collection('teachers').doc(uid).set({
        'uid': uid,
        'username': _usernameController.text.trim(),
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'teachingLocation': _locationController.text.trim(),
        'subjects': _selectedSubjects,
        'profileUrl': profileUrl,
        'certUrl': certUrl,
        'idProofUrl': idProofUrl,
        'status': 'pending',
        'role': 'teacher',
        'createdAt': FieldValue.serverTimestamp(),
      });

await FirebaseFirestore.instance
    .collection('users')
    .doc(_usernameController.text.trim())
    .set({
  'uid': uid,
  'username': _usernameController.text.trim(),
  'role': 'teacher',
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
                child: const Text("OK"),
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

  String? _validateField(String? val, String fieldName) {
    if (val == null || val.trim().isEmpty) {
      return "$fieldName is required";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Registration")),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => _pickImage((f) => setState(() => _profileImage = f)),
                              child: CircleAvatar(
                                radius: 50, 
                                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null, 
                                child: _profileImage == null ? const Icon(Icons.camera_alt, size: 50) : null
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController, 
                              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(), floatingLabelBehavior: FloatingLabelBehavior.auto),
                              validator: (val) => _validateField(val, "Full Name"),
                            ),
const SizedBox(height: 10),

TextFormField(
  controller: _usernameController,
  decoration: const InputDecoration(
    labelText: 'User ID',
    border: OutlineInputBorder(),
  ),
  validator: (value){
    if(value == null || value.trim().isEmpty){
      return "User ID required";
    }
    return null;
  },
),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _emailController, 
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(), floatingLabelBehavior: FloatingLabelBehavior.auto),
                              validator: (val) => _validateField(val, "Email Address"),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _passwordController, 
                              obscureText: true, 
                              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), floatingLabelBehavior: FloatingLabelBehavior.auto),
                              validator: (val) => _validateField(val, "Password"),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _phoneController, 
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(), floatingLabelBehavior: FloatingLabelBehavior.auto),
                              validator: (val) => _validateField(val, "Phone Number"),
                            ),
                            const SizedBox(height: 10),

                            TextFormField(
                              controller: _locationController,
                              decoration: InputDecoration(
                                labelText: 'Teaching Location',
                                border: const OutlineInputBorder(),
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.my_location),
                                  onPressed: _getCurrentLocation,
                                ),
                              ),
                            ),
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
                    Row(
                      children: [
                        Checkbox(
                          value: _isAccepted,
                          onChanged: (val) => setState(() => _isAccepted = val!),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(children: [
                              const TextSpan(text: "I accept the ", style: TextStyle(color: Colors.black)),
                              TextSpan(text: "Terms & Conditions", style: const TextStyle(color: Colors.blue), recognizer: TapGestureRecognizer()..onTap = _launchUrl),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _isAccepted ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: _isAccepted ? Colors.blue : Colors.grey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("REGISTER AS TEACHER", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    