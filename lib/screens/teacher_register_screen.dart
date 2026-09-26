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
  final _tuitionNameController = TextEditingController();
  final _experienceController = TextEditingController();

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
    _tuitionNameController.dispose();
    _experienceController.dispose();
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
      _locationController.text = "${position.latitude}, ${position.longitude}";
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields correctly."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one subject.'),
          backgroundColor: Colors.red,
        ),
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

      String profileUrl = "";
      if (_profileImage != null) {
        try {
          profileUrl = await _processAndUpload(_profileImage!, 'teachers/$uid/profile.jpg');
        } catch (e) {
          debugPrint("Profile image upload failed: $e");
        }
      }

      String certUrl = "";
      if (_qualificationCertificate != null) {
        try {
          certUrl = await _processAndUpload(_qualificationCertificate!, 'teachers/$uid/certificate.jpg');
        } catch (e) {
          debugPrint("Certificate upload failed: $e");
        }
      }

      String idProofUrl = "";
      if (_idProofImage != null) {
        try {
          idProofUrl = await _processAndUpload(_idProofImage!, 'teachers/$uid/id_proof.jpg');
        } catch (e) {
          debugPrint("ID Proof upload failed: $e");
        }
      }

      await FirebaseFirestore.instance.collection('teachers').doc(uid).set({
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'tuitionName': _tuitionNameController.text.trim(),
        'experience': _experienceController.text.trim().isEmpty ? '0' : _experienceController.text.trim(),
        'teachingLocation': _locationController.text.trim(),
        'subjects': _selectedSubjects,
        'profileUrl': profileUrl,
        'certUrl': certUrl,
        'idProofUrl': idProofUrl,
        'status': 'pending',
        'role': 'teacher',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': _emailController.text.trim(),
        'role': 'teacher',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Verify Your Email"),
            content: const Text("A verification link has been sent to your email. Please check your inbox and verify to login."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? "Registration failed. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateEmail(String? val) {
    if (val == null || val.trim().isEmpty) {
      return "Email Address is required";
    }
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(val.trim())) {
      return "Please enter a valid email address";
    }
    return null;
  }

  String? _validatePassword(String? val) {
    if (val == null || val.trim().isEmpty) {
      return "Password is required";
    }
    if (val.trim().length < 6) {
      return "Password must be at least 6 characters long";
    }
    return null;
  }

  String? _validatePhone(String? val) {
    if (val == null || val.trim().isEmpty) {
      return "Phone Number is required";
    }
    if (val.trim().length < 10) {
      return "Please enter a valid phone number";
    }
    return null;
  }

  String? _validateField(String? val, String fieldName) {
    if (val == null || val.trim().isEmpty) {
      return "$fieldName is required";
    }
    return null;
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blueAccent),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text("Teacher Registration", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: [
                    Card(
                      elevation: 2,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => _pickImage((f) => setState(() => _profileImage = f)),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 52,
                                    backgroundColor: Colors.blue.shade100,
                                    backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                                    child: _profileImage == null
                                        ? const Icon(Icons.person, size: 55, color: Colors.blueAccent)
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.blueAccent,
                                      child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _nameController,
                              decoration: _buildInputDecoration('Full Name', Icons.person_outline),
                              validator: (val) => _validateField(val, "Full Name"),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _buildInputDecoration('Email Address', Icons.email_outlined),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: _buildInputDecoration('Password', Icons.lock_outline),
                              validator: _validatePassword,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _buildInputDecoration('Phone Number', Icons.phone_outlined),
                              validator: _validatePhone,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _tuitionNameController,
                              decoration: _buildInputDecoration('Tuition / Institute Name', Icons.school_outlined),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _experienceController,
                              keyboardType: TextInputType.number,
                              decoration: _buildInputDecoration('Teaching Experience (in Years)', Icons.work_outline),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _locationController,
                              decoration: _buildInputDecoration(
                                'Teaching Location',
                                Icons.location_on_outlined,
                                suffix: IconButton(
                                  icon: const Icon(Icons.my_location, color: Colors.blueAccent),
                                  onPressed: _getCurrentLocation,
                                ),
                              ),
                              validator: (val) => _validateField(val, "Teaching Location"),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      elevation: 2,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Select Subjects",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "${_selectedSubjects.length} Selected",
                                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _allSubjects.map((s) {
                                final isSelected = _selectedSubjects.contains(s);
                                return FilterChip(
                                  label: Text(s),
                                  selected: isSelected,
                                  selectedColor: Colors.blueAccent.withOpacity(0.2),
                                  checkmarkColor: Colors.blueAccent,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.blueAccent : Colors.black87,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
                                    ),
                                  ),
                                  onSelected: (val) => setState(() {
                                    val ? _selectedSubjects.add(s) : _selectedSubjects.remove(s);
                                  }),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      elevation: 2,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.workspace_premium, color: Colors.blueAccent),
                              title: const Text("Qualification Certificate (Optional)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _qualificationCertificate != null ? Colors.green : Colors.blueAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: Icon(_qualificationCertificate != null ? Icons.check : Icons.upload_file, size: 16, color: Colors.white),
                                label: Text(_qualificationCertificate != null ? "Selected" : "Upload", style: const TextStyle(color: Colors.white, fontSize: 12)),
                                onPressed: () => _pickImage((f) => setState(() => _qualificationCertificate = f)),
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.badge_outlined, color: Colors.blueAccent),
                              title: const Text("ID Proof - NID/Passport/Aadhaar (Optional)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              trailing: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _idProofImage != null ? Colors.green : Colors.blueAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: Icon(_idProofImage != null ? Icons.check : Icons.upload_file, size: 16, color: Colors.white),
                                label: Text(_idProofImage != null ? "Selected" : "Upload", style: const TextStyle(color: Colors.white, fontSize: 12)),
                                onPressed: () => _pickImage((f) => setState(() => _idProofImage = f)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Checkbox(
                          value: _isAccepted,
                          activeColor: Colors.blueAccent,
                          onChanged: (val) => setState(() => _isAccepted = val!),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(children: [
                              const TextSpan(text: "I accept the ", style: TextStyle(color: Colors.black87, fontSize: 13)),
                              TextSpan(
                                text: "Terms & Conditions",
                                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                recognizer: TapGestureRecognizer()..onTap = _launchUrl,
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: _isAccepted ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: _isAccepted ? Colors.blueAccent : Colors.grey.shade400,
                        elevation: _isAccepted ? 3 : 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "REGISTER AS TEACHER",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}