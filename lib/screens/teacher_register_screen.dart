import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  List<String> _selectedSubjects = [];
  String? _currentLocation;
  File? _profileImage;
  String? _gender;
  bool _isLoading = false;

  final List<String> _allSubjects = [
    'Math', 'English', 'Physics', 'Chemistry', 'Biology', 'History', 'Geography'
  ];

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
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

    if (name.isEmpty || email.isEmpty || password.isEmpty || phone.isEmpty || location.isEmpty || _gender == null || _profileImage == null || _selectedSubjects.isEmpty || _currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await AuthService().registerWithEmail(email, password);
      final uid = userCredential.user!.uid;

      await FirestoreService().saveTeacherData(uid, {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'teachingLocation': location,
        'currentLocation': _currentLocation,
        'gender': _gender,
        'subjects': _selectedSubjects,
        'createdAt': DateTime.now(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
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