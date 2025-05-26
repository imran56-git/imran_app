import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';

class TeacherRegistrationScreen extends StatefulWidget {
  const TeacherRegistrationScreen({super.key});

  @override
  State<TeacherRegistrationScreen> createState() => _TeacherRegistrationScreenState();
}

class _TeacherRegistrationScreenState extends State<TeacherRegistrationScreen> {
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

  final List<String> _allSubjects = [
    'Math', 'English', 'Physics', 'Chemistry', 'Biology', 'History', 'Geography'
  ];

  Future<void> _pickImage(Function(File) onPicked) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) onPicked(File(picked.path));
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      setState(() {
        _currentLocation = '${position.latitude}, ${position.longitude}';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location error: $e')));
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final location = _locationController.text.trim();
    final qualification = _qualificationController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || phone.isEmpty || location.isEmpty ||
        qualification.isEmpty || _gender == null || _profileImage == null || _selectedSubjects.isEmpty ||
        _currentLocation == null || _qualificationCertificate == null || _idProofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await AuthService().registerWithEmail(email, password);
      final uid = userCredential.user!.uid;

      // Upload Images
      final profileRef = FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
      await profileRef.putFile(_profileImage!);
      final profileUrl = await profileRef.getDownloadURL();

      final certRef = FirebaseStorage.instance.ref().child('qualification_certificates/$uid.jpg');
      await certRef.putFile(_qualificationCertificate!);
      final certUrl = await certRef.getDownloadURL();

      final idProofRef = FirebaseStorage.instance.ref().child('id_proofs/$uid.jpg');
      await idProofRef.putFile(_idProofImage!);
      final idProofUrl = await idProofRef.getDownloadURL();

      await FirestoreService().saveTeacherData(uid, {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'teachingLocation': location,
        'currentLocation': _currentLocation,
        'gender': _gender,
        'subjects': _selectedSubjects,
        'qualification': qualification,
        'profileImageUrl': profileUrl,
        'qualificationCertificateUrl': certUrl,
        'idProofUrl': idProofUrl,
        'createdAt': DateTime.now(),
        'role': 'teacher',
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration Successful')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    setState(() => _isLoading = false);
  }

  Widget _buildSubjectCheckbox(String subject) {
    return CheckboxListTile(
      title: Text(subject),
      value: _selectedSubjects.contains(subject),
      onChanged: (selected) {
        setState(() {
          if (selected!) {
            _selectedSubjects.add(subject);
          } else {
            _selectedSubjects.remove(subject);
          }
        });
      },
    );
  }

  Widget _buildImageRow(String label, File? file, VoidCallback onTap) {
    return Row(
      children: [
        Expanded(child: Text(file != null ? '$label Selected' : 'No $label selected')),
        IconButton(icon: const Icon(Icons.upload_file), onPressed: onTap),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _pickImage((file) => setState(() => _profileImage = file)),
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                child: _profileImage == null ? const Icon(Icons.add_a_photo, size: 40) : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name')),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number')),
            TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Teaching Location')),
            TextField(controller: _qualificationController, decoration: const InputDecoration(labelText: 'Qualification')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(_currentLocation ?? 'Current location not fetched')),
                IconButton(icon: const Icon(Icons.my_location), onPressed: _fetchCurrentLocation),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
              onChanged: (val) => setState(() => _gender = val),
            ),
            const SizedBox(height: 12),
            const Text('Select Subjects:', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._allSubjects.map(_buildSubjectCheckbox).toList(),
            const SizedBox(height: 12),
            _buildImageRow('Qualification Certificate', _qualificationCertificate, () => _pickImage((file) => setState(() => _qualificationCertificate = file))),
            _buildImageRow('ID Proof', _idProofImage, () => _pickImage((file) => setState(() => _idProofImage = file))),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _submit, child: const Text('Register')),
          ],
        ),
      ),
    );
  }
}