import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Import your custom screens here
// import 'chat_screen.dart'; 
// import 'student_payment_confirmation_screen.dart';

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

  // --- COMPLETE SUBJECT LIST FROM YOUR ORIGINAL CODE ---
  final List<String> allSubjects = [
    'Mathematics', 'Physics', 'Chemistry', 'Biology', 'Computer Science',
    'English', 'Bengali', 'Hindi', 'Sanskrit', 'History', 'Geography',
    'Civics', 'Political Science', 'Economics', 'Philosophy', 'Psychology',
    'Sociology', 'Environmental Studies', 'General Science', 'Life Science',
    'Physical Science', 'Social Studies', 'Moral Science', 'Science (Junior Level)',
    'Fine Arts', 'Visual Arts', 'Performing Arts', 'Music', 'Dance', 'Drama/Theatre',
    'Art & Craft', 'Painting', 'Drawing', 'French', 'Spanish', 'German', 'Arabic',
    'Chinese', 'Japanese', 'Korean', 'Pali', 'Urdu', 'Business Studies', 'Accounting',
    'Finance', 'Entrepreneurship', 'Marketing', 'Commerce', 'Taxation', 'Banking',
    'Information Technology', 'Web Development', 'App Development', 'Cyber Security',
    'Data Science', 'Artificial Intelligence', 'Robotics', 'Machine Learning',
    'Electrical Engineering Basics', 'Mechanical Engineering Basics', 'Electronics',
    '3D Design & Printing', 'Physical Education', 'Yoga', 'Health & Hygiene',
    'Nutrition & Dietetics', 'Home Science', 'First Aid', 'Life Skills',
    'Public Speaking', 'Leadership Skills', 'Soft Skills', 'General Knowledge',
    'Alphabet & Phonics', 'Storytelling', 'Rhymes', 'Basic Drawing',
    'Counting & Numbers', 'Shapes & Colors', 'Moral Education', 'Astronomy',
    'Statistics', 'Library Science', 'Media Studies', 'Photography',
    'Film & Television', 'Fashion Design', 'Interior Design', 'Agricultural Science',
    'Legal Studies', 'Criminology', 'Tourism & Hospitality', 'Environmental Science',
    'Ethics', 'Gender Studies',
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

    try {
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
    } catch (e) {
      debugPrint("Error fetching data: $e");
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> updateStudentProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => isLoading = true);

    try {
      String? imageUrl = studentData?['profileImageUrl'];
      if (_selectedImage != null) {
        final ref = _storage.ref().child('students/$uid/profile.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      await _firestore.collection('students').doc(uid).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'bio': _bioController.text.trim(),
        'gender': gender,
        'studentClass': studentClass,
        'interestedSubjects': selectedSubjects,
        'profileImageUrl': imageUrl,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile Updated Successfully!')),
        );
        setState(() {
          isEditing = false;
          _selectedImage = null;
        });
        fetchStudentData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
          const SizedBox(height: 4),
          Text(value.isEmpty ? "N/A" : value, style: const TextStyle(fontSize: 16)),
          const Divider(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = studentData?['profileImageUrl'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Student Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
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
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // --- PROFILE IMAGE SECTION ---
                  Center(
                    child: GestureDetector(
                      onTap: isEditing ? pickImage : null,
                      child: CircleAvatar(
                        radius: 65,
                        backgroundColor: Colors.indigo[50],
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : (imageUrl != null ? NetworkImage(imageUrl) : null) as ImageProvider?,
                        child: (imageUrl == null && _selectedImage == null)
                            ? const Icon(Icons.person, size: 65, color: Colors.indigo)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // --- TEXT FIELDS / INFO ROWS ---
                  isEditing ? _buildEditForm() : _buildProfileView(),

                  const SizedBox(height: 30),

                  // --- PAYMENT BUTTON (Only in View Mode) ---
                  if (!isEditing) _buildPaymentButton(),

                  // --- CHAT SECTION (Only in View Mode) ---
                  if (!isEditing) _buildRecentChatsSection(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        _customEditField("Full Name", _nameController),
        _customEditField("Phone Number", _phoneController),
        _customEditField("Location", _locationController),
        _customEditField("Bio", _bioController, maxLines: 3),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: gender,
          decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
          onChanged: (val) => setState(() => gender = val),
          items: const [
            DropdownMenuItem(value: "Male", child: Text("Male")),
            DropdownMenuItem(value: "Female", child: Text("Female")),
          ],
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(
          value: studentClass,
          decoration: const InputDecoration(labelText: "Class/Level", border: OutlineInputBorder()),
          onChanged: (val) => setState(() => studentClass = val),
          items: classOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        ),
        const SizedBox(height: 20),
        _buildSubjectPicker(),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: updateStudentProfile,
            child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow("Name", _nameController.text),
        _buildInfoRow("Phone", _phoneController.text),
        _buildInfoRow("Location", _locationController.text),
        _buildInfoRow("Bio", _bioController.text),
        _buildInfoRow("Gender", gender ?? "N/A"),
        _buildInfoRow("Class", studentClass ?? "N/A"),
        const SizedBox(height: 10),
        const Text("Interested Subjects", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: selectedSubjects.map((s) => Chip(label: Text(s))).toList(),
        ),
      ],
    );
  }

  Widget _buildSubjectPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Interested Subjects", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _subjectSearchController,
          decoration: const InputDecoration(hintText: "Search Subject...", prefixIcon: Icon(Icons.search)),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Container(
          height: 200,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: allSubjects
                .where((s) => s.toLowerCase().contains(_subjectSearchController.text.toLowerCase()))
                .map((s) => CheckboxListTile(
                      title: Text(s),
                      value: selectedSubjects.contains(s),
                      onChanged: (val) {
                        setState(() {
                          val! ? selectedSubjects.add(s) : selectedSubjects.remove(s);
                        });
                      },
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text("UPLOAD PAYMENT CONFIRMATION"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
          onPressed: () {
            final tId = studentData?['connectedTeacherId'] ?? 'demo_id';
            // Navigator.push(context, MaterialPageRoute(builder: (_) => StudentPaymentConfirmationScreen(teacherId: tId)));
          },
        ),
      ),
    );
  }

  Widget _buildRecentChatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Divider(),
        const Text("Recent Conversations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('chats')
              .where('participants', arrayContains: _auth.currentUser!.uid)
              .orderBy('lastMessageTime', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text("No recent messages.");
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final chat = snapshot.data!.docs[index];
                final tId = (chat['participants'] as List).firstWhere((id) => id != _auth.currentUser!.uid);
                return _buildChatTile(tId, chat);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildChatTile(String teacherId, QueryDocumentSnapshot chat) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('teachers').doc(teacherId).get(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox();
        final teacher = snap.data!.data() as Map<String, dynamic>;
        return ListTile(
          leading: CircleAvatar(backgroundImage: teacher['profileImageUrl'] != null ? NetworkImage(teacher['profileImageUrl']) : null),
          title: Text(teacher['name'] ?? 'Teacher'),
          subtitle: Text(chat['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(...)));
          },
        );
      },
    );
  }

  Widget _customEditField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
