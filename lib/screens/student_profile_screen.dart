import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Map<String, dynamic>? studentData;
  bool isLoading = true;
  bool isEditing = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();
  final _subjectSearchController = TextEditingController();
  String? gender;
  String? studentClass;
  List<String> selectedSubjects = [];

  final List<String> allSubjects = [
'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Computer Science',
    'English',
    'Bengali',
    'Hindi',
    'Sanskrit',
    'History',
    'Geography',
    'Civics',
    'Political Science',
    'Economics',
    'Philosophy',
    'Psychology',
    'Sociology',
    'Environmental Studies',
    'General Science',
    'Life Science',
    'Physical Science',
    'Social Studies',
    'Moral Science',
    'Science (Junior Level)',

    // Arts & Humanities
    'Fine Arts',
    'Visual Arts',
    'Performing Arts',
    'Music',
    'Dance',
    'Drama/Theatre',
    'Art & Craft',
    'Painting',
    'Drawing',

    // Languages
    'French',
    'Spanish',
    'German',
    'Arabic',
    'Chinese',
    'Japanese',
    'Korean',
    'Pali',
    'Urdu',

    // Commerce & Business
    'Business Studies',
    'Accounting',
    'Finance',
    'Entrepreneurship',
    'Marketing',
    'Commerce',
    'Taxation',
    'Banking',

    // Technology & Vocational
    'Information Technology',
    'Web Development',
    'App Development',
    'Cyber Security',
    'Data Science',
    'Artificial Intelligence',
    'Robotics',
    'Machine Learning',
    'Electrical Engineering Basics',
    'Mechanical Engineering Basics',
    'Electronics',
    '3D Design & Printing',

    // Health, Physical & Life Skills
    'Physical Education',
    'Yoga',
    'Health & Hygiene',
    'Nutrition & Dietetics',
    'Home Science',
    'First Aid',
    'Life Skills',
    'Public Speaking',
    'Leadership Skills',
    'Soft Skills',
    'General Knowledge',

    // Early Childhood & Junior Level
    'Alphabet & Phonics',
    'Storytelling',
    'Rhymes',
    'Basic Drawing',
    'Counting & Numbers',
    'Shapes & Colors',
    'Moral Education',

    // Optional & Miscellaneous
    'Astronomy',
    'Statistics',
    'Library Science',
    'Media Studies',
    'Photography',
    'Film & Television',
    'Fashion Design',
    'Interior Design',
    'Agricultural Science',
    'Legal Studies',
    'Criminology',
    'Tourism & Hospitality',
    'Environmental Science',
    'Ethics',
    'Gender Studies',
  ];

  final List<String> classOptions = [
    'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5',
    'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10',
    'Class 11', 'Class 12', 'College 1st Year', 'College 2nd Year',
    'University 1st Year', 'University 2nd Year', 'University 3rd Year',
    'University 4th Year', 'Others',
  ];

  @override
  void initState() {
    super.initState();
    fetchStudentData();
  }

  Future<void> fetchStudentData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firestore.collection('students').doc(uid).get();
    if (doc.exists) {
      studentData = doc.data();
      _nameController.text = studentData?['name'] ?? '';
      _phoneController.text = studentData?['phone'] ?? '';
      _locationController.text = studentData?['location'] ?? '';
      _bioController.text = studentData?['bio'] ?? '';
      gender = studentData?['gender'];
      studentClass = studentData?['studentClass'];
      selectedSubjects = List<String>.from(studentData?['interestedSubjects'] ?? []);
    }

    setState(() => isLoading = false);
  }

  Future<void> updateStudentProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    String? imageUrl = studentData?['profileImageUrl'];
    if (_selectedImage != null) {
      final ref = _storage.ref().child('students/$uid/profile.jpg');
      await ref.putFile(_selectedImage!);
      imageUrl = await ref.getDownloadURL();
    }

    await _firestore.collection('students').doc(uid).update({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'location': _locationController.text.trim(),
      'bio': _bioController.text.trim(),
      'gender': gender,
      'studentClass': studentClass,
      'interestedSubjects': selectedSubjects,
      'profileImageUrl': imageUrl,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );

    setState(() {
      isEditing = false;
      _selectedImage = null;
    });

    fetchStudentData();
  }

  Future<void> pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Widget buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: isEditing
          ? TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                labelText: label,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    controller.text.isNotEmpty ? controller.text : 'N/A',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = studentData?['profileImageUrl'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Profile"),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => isEditing = !isEditing),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: isEditing ? pickImage : null,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : imageUrl != null
                              ? NetworkImage(imageUrl)
                              : const AssetImage("assets/images/default_avatar.png") as ImageProvider,
                    ),
                  ),
                  const SizedBox(height: 24),
                  buildTextField("Name", _nameController),
                  buildTextField("Phone", _phoneController),
                  buildTextField("Location", _locationController),
                  buildTextField("Bio", _bioController, maxLines: 3),

                  const SizedBox(height: 12),
                  isEditing
                      ? DropdownButtonFormField<String>(
                          value: gender,
                          onChanged: (val) => setState(() => gender = val),
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Male', child: Text('Male')),
                            DropdownMenuItem(value: 'Female', child: Text('Female')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                        )
                      : buildTextField("Gender", TextEditingController(text: gender ?? 'N/A')),

                  const SizedBox(height: 16),
                  isEditing
                      ? DropdownButtonFormField<String>(
                          value: studentClass,
                          onChanged: (val) => setState(() => studentClass = val),
                          decoration: const InputDecoration(
                            labelText: 'Class',
                            border: OutlineInputBorder(),
                          ),
                          items: classOptions.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                        )
                      : buildTextField("Class", TextEditingController(text: studentClass ?? 'N/A')),

                  const SizedBox(height: 24),
                  const Divider(),
                  const Text("Select Interested Subjects",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),

                  if (isEditing)
                    Column(
                      children: [
                        TextField(
                          controller: _subjectSearchController,
                          decoration: const InputDecoration(
                            hintText: "Search Subject",
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: allSubjects
                              .where((subject) => subject.toLowerCase().contains(_subjectSearchController.text.toLowerCase()))
                              .map((subject) {
                            final selected = selectedSubjects.contains(subject);
                            return FilterChip(
                              label: Text(subject),
                              selected: selected,
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    selectedSubjects.add(subject);
                                  } else {
                                    selectedSubjects.remove(subject);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: selectedSubjects.isEmpty
                          ? [const Text('N/A')]
                          : selectedSubjects
                              .map((s) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text('• $s'),
                                  ))
                              .toList(),
                    ),

                  const SizedBox(height: 32),
                  if (isEditing)
                    ElevatedButton(
                      onPressed: updateStudentProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Save Changes"),
                    ),
                ],
              ),
            ),
    );
  }
}