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
import '../services/gemini_service.dart';
import 'teacher_liveness_check_screen.dart';

class TeacherRegistrationScreen extends StatefulWidget {
  const TeacherRegistrationScreen({super.key});

  @override
  State<TeacherRegistrationScreen> createState() =>
      _TeacherRegistrationScreenState();
}

class _TeacherRegistrationScreenState
    extends State<TeacherRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _tuitionNameController = TextEditingController();
  final _experienceController = TextEditingController();
  final _subjectInputController = TextEditingController();

  List<String> _selectedSubjects = [];
  File? _profileImage;
  File? _qualificationCertificate;
  File? _idProofImage;
  File? _verifiedFaceFile;

  bool _isLoading = false;
  bool _isAnalyzingDoc = false;
  bool _isAccepted = false;
  bool _isLivenessVerified = false;
  bool _obscurePassword = true;

  String _selectedIdType = "Aadhaar Card";
  Map<String, dynamic>? _scannedCertificateData;
  bool _isCertificateConfirmed = false;
  String _analysisStatusText = "";

  final GeminiService _geminiService = GeminiService();
  final String _policyUrl =
      "https://docs.google.com/document/d/1pLnjsGpdQwmbdytG7ZC5Nro7LHaOmgy8nSLCKGEgy0E/edit?usp=drivesdk";

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _tuitionNameController.dispose();
    _experienceController.dispose();
    _subjectInputController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Function(File) onPicked) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
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

  Future<String> _processAndUpload(File file, String path) async {
    File? compressedFile = await ImageHelper.compressImage(file);
    File fileToUpload = compressedFile ?? file;
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(fileToUpload);
    return await ref.getDownloadURL();
  }

  void _addSubject() {
    final subject = _subjectInputController.text.trim();
    if (subject.isNotEmpty && !_selectedSubjects.contains(subject)) {
      setState(() {
        _selectedSubjects.add(subject);
        _subjectInputController.clear();
      });
    }
  }

  void _showIdProofSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Government ID Type",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Choose the official document you wish to upload for verification.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _idTypeTile("Aadhaar Card", Icons.fingerprint_rounded),
            _idTypeTile("PAN Card", Icons.credit_card_rounded),
            _idTypeTile("Passport", Icons.airplanemode_active_rounded),
          ],
        ),
      ),
    );
  }

  Widget _idTypeTile(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      trailing: _selectedIdType == title
          ? const Icon(Icons.check_circle, color: Colors.green)
          : null,
      onTap: () {
        Navigator.pop(context);
        setState(() => _selectedIdType = title);
        _pickAndVerifyIdProof();
      },
    );
  }

  Future<void> _pickAndVerifyIdProof() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final File idFile = File(picked.path);
    setState(() {
      _isAnalyzingDoc = true;
      _analysisStatusText = "Scanning $_selectedIdType with forensic AI...";
    });

    try {
      final fullName = _nameController.text.trim();
      final result = await _geminiService.verifyGovernmentIdDocument(
        documentFile: idFile,
        selectedDocType: _selectedIdType,
        expectedFullName: fullName,
      );

      if (!mounted) return;

      if (result['isValid'] == true && result['nameMatches'] == true) {
        setState(() {
          _idProofImage = idFile;
          _isAnalyzingDoc = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$_selectedIdType verified successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _isAnalyzingDoc = false);
        _showErrorDialog(
          "ID Verification Failed",
          result['errorMessage'] ?? "Document verification failed.",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzingDoc = false);
        _showErrorDialog("Error", "Could not verify ID proof: $e");
      }
    }
  }

  Future<void> _pickAndVerifyCertificate() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final File certFile = File(picked.path);
    setState(() {
      _isAnalyzingDoc = true;
      _analysisStatusText = "Scanning qualification certificate...";
      _scannedCertificateData = null;
      _isCertificateConfirmed = false;
    });

    try {
      final fullName = _nameController.text.trim();
      final result = await _geminiService.verifyQualificationCertificate(
        certificateFile: certFile,
        expectedFullName: fullName,
      );

      if (!mounted) return;

      if (result['isValid'] == true) {
        setState(() {
          _qualificationCertificate = certFile;
          _scannedCertificateData = result;
          _isAnalyzingDoc = false;
        });
      } else {
        setState(() => _isAnalyzingDoc = false);
        _showErrorDialog(
          "Invalid Certificate",
          result['errorMessage'] ??
              "Could not scan valid educational certificate.",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzingDoc = false);
        _showErrorDialog("Error", "Could not process certificate: $e");
      }
    }
  }

  Future<void> _startFaceLivenessCheck() async {
    if (_idProofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please upload and verify your ID proof first."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherLivenessCheckScreen(
          registrationData: {'name': _nameController.text.trim()},
        ),
      ),
    );

    if (result != null && result is Map && result['success'] == true) {
      final File liveFace = result['faceFile'] as File;

      setState(() {
        _isAnalyzingDoc = true;
        _analysisStatusText =
            "Performing 85%+ biometric face match with ID proof...";
      });

      try {
        final matchResult = await _geminiService.verifyFaceMatchWithIdCard(
          idDocumentFile: _idProofImage!,
          liveFaceFile: liveFace,
          minimumSimilarityThreshold: 85.0,
        );

        if (!mounted) return;

        if (matchResult['isMatched'] == true) {
          setState(() {
            _verifiedFaceFile = liveFace;
            _isLivenessVerified = true;
            _isAnalyzingDoc = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Biometric Face Match Verified (85%+) Successfully!",
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() => _isAnalyzingDoc = false);
          _showErrorDialog(
            "Face Match Failed",
            matchResult['message'] ?? "Face does not match ID proof.",
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isAnalyzingDoc = false);
          _showErrorDialog("Error", "Biometric comparison error: $e");
        }
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
          content: Text('Please add at least one subject.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_qualificationCertificate == null || !_isCertificateConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please upload and confirm your Qualification Certificate.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_idProofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Government ID Proof is mandatory.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isLivenessVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete Face Liveness & Biometric Verification.',
          ),
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

      String profileUrl = "";
      if (_profileImage != null) {
        try {
          profileUrl = await _processAndUpload(
            _profileImage!,
            'teachers/$uid/profile.jpg',
          );
          await user.updatePhotoURL(profileUrl);
        } catch (_) {}
      }

      String certUrl = "";
      try {
        certUrl = await _processAndUpload(
          _qualificationCertificate!,
          'teachers/$uid/certificate.jpg',
        );
      } catch (_) {}

      String idProofUrl = "";
      try {
        idProofUrl = await _processAndUpload(
          _idProofImage!,
          'teachers/$uid/id_proof.jpg',
        );
      } catch (_) {}

      final String fullName = _nameController.text.trim();
      final String email = _emailController.text.trim();
      final String phone = _phoneController.text.trim();
      final String tuitionName = _tuitionNameController.text.trim();
      final String experience = _experienceController.text.trim().isEmpty
          ? '0'
          : _experienceController.text.trim();
      final String teachingLocation = _locationController.text.trim();

      final String degreeTitle =
          _scannedCertificateData?['qualificationTitle']?.toString() ?? '';
      final String institution =
          _scannedCertificateData?['institutionOrCollege']?.toString() ?? '';
      final String university =
          _scannedCertificateData?['boardOrUniversity']?.toString() ?? '';

      final Map<String, dynamic> teacherData = {
        'uid': uid,
        'fybttUid': uid,
        'name': fullName,
        'fullName': fullName,
        'displayName': fullName,
        'email': email,
        'phone': phone,
        'tuitionName': tuitionName,
        'instituteName': tuitionName,
        'coachingName': tuitionName,
        'experience': experience,
        'experienceYears': int.tryParse(experience) ?? 0,
        'teachingLocation': teachingLocation,
        'address': teachingLocation,
        'location': teachingLocation,
        'subjects': _selectedSubjects,
        'subject': _selectedSubjects.isNotEmpty ? _selectedSubjects.first : '',
        'profileUrl': profileUrl,
        'profileImageUrl': profileUrl,
        'profilePic': profileUrl,
        'photoUrl': profileUrl,
        'certUrl': certUrl,
        'certificateUrl': certUrl,
        'idProofUrl': idProofUrl,
        'idProofType': _selectedIdType,
        'qualificationDetails': _scannedCertificateData ?? {},
        'degree': degreeTitle,
        'qualification': degreeTitle,
        'credentials': degreeTitle.isNotEmpty
            ? "$degreeTitle, $institution"
            : "Verified Educator on FYBTT",
        'college': institution,
        'university': university,
        'isVerified': true,
        'status': 'approved',
        'role': 'teacher',
        'userType': 'teacher',
        'hasGoldenBadge': false,
        'studentCount': 0,
        'averageRating': 5.0,
        'rating': 5.0,
        'isOnline': false,
        'fcmToken': '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(uid)
          .set(teacherData, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(teacherData, SetOptions(merge: true));

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text("Registration Successful"),
            content: const Text(
              "Your academic credentials, ID proof, and biometric face match have been verified successfully. Please check your email to verify your account.",
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? "Registration failed."),
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

  InputDecoration _buildInputDecoration(String label, IconData icon,
      {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.blueAccent, size: 22),
      suffixIcon: suffix,
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
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          "Teacher Registration",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: _isLoading || _isAnalyzingDoc
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.blueAccent),
                  const SizedBox(height: 18),
                  Text(
                    _isAnalyzingDoc
                        ? _analysisStatusText
                        : "Registering educator account...",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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
                          GestureDetector(
                            onTap: () => _pickImage(
                                (f) => setState(() => _profileImage = f)),
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 54,
                                  backgroundColor: Colors.blue.shade50,
                                  backgroundImage: _profileImage != null
                                      ? FileImage(_profileImage!)
                                      : null,
                                  child: _profileImage == null
                                      ? const Icon(Icons.person,
                                          size: 60, color: Colors.blueAccent)
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent,
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
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            decoration: _buildInputDecoration(
                                'Full Name', Icons.person_outline),
                            validator: (val) => val == null || val.trim().isEmpty
                                ? "Full Name is required"
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _buildInputDecoration(
                                'Email Address', Icons.email_outlined),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return "Email is required";
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(val.trim())) {
                                return "Enter valid email";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: _buildInputDecoration(
                              'Password',
                              Icons.lock_outline,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return "Password is required";
                              }
                              if (val.trim().length < 6) {
                                return "Password must be at least 6 chars";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _buildInputDecoration(
                                'Phone Number', Icons.phone_outlined),
                            validator: (val) =>
                                val == null || val.trim().length < 10
                                    ? "Enter valid phone"
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _tuitionNameController,
                            decoration: _buildInputDecoration(
                                'Tuition / Institute Name',
                                Icons.school_outlined),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _experienceController,
                            keyboardType: TextInputType.number,
                            decoration: _buildInputDecoration(
                                'Teaching Experience (in Years)',
                                Icons.work_outline),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _locationController,
                            decoration: _buildInputDecoration(
                              'Teaching Location',
                              Icons.location_on_outlined,
                              suffix: IconButton(
                                icon: const Icon(Icons.my_location,
                                    color: Colors.blueAccent),
                                onPressed: _getCurrentLocation,
                              ),
                            ),
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                    ? "Location is required"
                                    : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Subjects & Expertise",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _subjectInputController,
                                  decoration: _buildInputDecoration(
                                      'Add Subject (e.g. Physics)',
                                      Icons.book_outlined),
                                  onFieldSubmitted: (_) => _addSubject(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _addSubject,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  minimumSize: const Size(54, 54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child:
                                    const Icon(Icons.add, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedSubjects.map((subject) {
                              return Chip(
                                label: Text(
                                  subject,
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: Colors.blue.shade50,
                                deleteIcon: const Icon(Icons.close,
                                    size: 16, color: Colors.blueAccent),
                                onDeleted: () {
                                  setState(() {
                                    _selectedSubjects.remove(subject);
                                  });
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Verification & Documents",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.workspace_premium,
                                color: Colors.blueAccent),
                            title: const Text(
                              "Qualification Certificate (Required)",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _qualificationCertificate != null
                                        ? Colors.green
                                        : Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: Icon(
                                _qualificationCertificate != null
                                    ? Icons.check
                                    : Icons.upload_file,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                _qualificationCertificate != null
                                    ? "Selected"
                                    : "Upload",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: _pickAndVerifyCertificate,
                            ),
                          ),
                          if (_scannedCertificateData != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Degree: ${_scannedCertificateData!['qualificationTitle']}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Institution: ${_scannedCertificateData!['institutionOrCollege']}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    "Board/University: ${_scannedCertificateData!['boardOrUniversity']}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    "Candidate: ${_scannedCertificateData!['candidateName']}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _isCertificateConfirmed,
                                        activeColor: Colors.blueAccent,
                                        onChanged: (val) => setState(
                                          () =>
                                              _isCertificateConfirmed = val!,
                                        ),
                                      ),
                                      const Expanded(
                                        child: Text(
                                          "I confirm that the extracted certificate details above are accurate.",
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Divider(height: 24),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.badge_outlined,
                                color: Colors.blueAccent),
                            title: Text(
                              "ID Proof - $_selectedIdType (Required)",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _idProofImage != null
                                    ? Colors.green
                                    : Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: Icon(
                                _idProofImage != null
                                    ? Icons.check
                                    : Icons.upload_file,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                _idProofImage != null ? "Selected" : "Upload",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: _showIdProofSelector,
                            ),
                          ),
                          const Divider(height: 24),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.face,
                                color: Colors.blueAccent),
                            title: const Text(
                              "Face Liveness & Biometric Verification",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isLivenessVerified
                                    ? Colors.green
                                    : Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: Icon(
                                _isLivenessVerified
                                    ? Icons.check_circle
                                    : Icons.camera_front,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                _isLivenessVerified
                                    ? "Verified (85%+)"
                                    : "Verify Face",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: _startFaceLivenessCheck,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: _isAccepted,
                          activeColor: Colors.blueAccent,
                          onChanged: (val) =>
                              setState(() => _isAccepted = val!),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(children: [
                              const TextSpan(
                                text: "I accept the ",
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                ),
                              ),
                              TextSpan(
                                text: "Terms & Conditions",
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = _launchUrl,
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isAccepted ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        backgroundColor: _isAccepted
                            ? Colors.blueAccent
                            : Colors.grey.shade300,
                        elevation: _isAccepted ? 4 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "REGISTER AS TEACHER",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
