import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'chat_screen.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

Widget buildTeacherCard(Map<String, dynamic> data) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 3,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data['name'] ?? 'No Name',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text("Location: ${data['currentLocation'] ?? 'Unknown'}"),
          const SizedBox(height: 6),
          if (data['subjects'] != null)
            Wrap(
              spacing: 6,
              children: List<Widget>.from(
                (data['subjects'] as List).map((subj) => Chip(label: Text(subj))),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.person),
                label: const Text("View Profile"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeacherProfileScreen(
                        teacherId: data['uid'],
                      ),
                    ),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.map),
                label: const Text("Open Map"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GoogleMapScreen(
                        teacherLocation: data['currentLocation'],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? teacherData;
  bool isLoading = true;
  bool isEditing = false;
  File? _selectedImage;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _subjectSearchController = TextEditingController();
  String? gender;

  final List<String> allSubjects = [
    // Core Academic Subjects
    'Mathematics', 'Physics', 'Chemistry', 'Biology', 'Computer Science',
    'English', 'Bengali', 'Hindi', 'Sanskrit', 'History', 'Geography', 'Civics',
    'Political Science', 'Economics', 'Philosophy', 'Psychology', 'Sociology',
    'Environmental Studies', 'General Science', 'Life Science', 'Physical Science',
    'Social Studies', 'Moral Science', 'Science (Junior Level)',

    // Arts & Humanities
    'Fine Arts', 'Visual Arts', 'Performing Arts', 'Music', 'Dance', 'Drama/Theatre',
    'Art & Craft', 'Painting', 'Drawing',

    // Languages
    'French', 'Spanish', 'German', 'Arabic', 'Chinese', 'Japanese', 'Korean',
    'Pali', 'Urdu',

    // Commerce & Business
    'Business Studies', 'Accounting', 'Finance', 'Entrepreneurship', 'Marketing',
    'Commerce', 'Taxation', 'Banking',

    // Technology & Vocational
    'Information Technology', 'Web Development', 'App Development', 'Cyber Security',
    'Data Science', 'Artificial Intelligence', 'Robotics', 'Machine Learning',
    'Electrical Engineering Basics', 'Mechanical Engineering Basics', 'Electronics',
    '3D Design & Printing',

    // Health, Physical & Life Skills
    'Physical Education', 'Yoga', 'Health & Hygiene', 'Nutrition & Dietetics',
    'Home Science', 'First Aid', 'Life Skills', 'Public Speaking', 'Leadership Skills',
    'Soft Skills', 'General Knowledge',

    // Early Childhood & Junior Level
    'Alphabet & Phonics', 'Storytelling', 'Rhymes', 'Basic Drawing', 'Counting & Numbers',
    'Shapes & Colors', 'Moral Education',

    // Optional & Miscellaneous
    'Astronomy', 'Statistics', 'Library Science', 'Media Studies', 'Photography',
    'Film & Television', 'Fashion Design', 'Interior Design', 'Agricultural Science',
    'Legal Studies', 'Criminology', 'Tourism & Hospitality', 'Environmental Science',
    'Ethics', 'Gender Studies',
  ];

  List<String> selectedSubjects = [];

bool isFollowing = false;

@override
void initState() {
  super.initState();
  fetchTeacherData();         // 
  checkFollowStatus();        // 
}

void checkFollowStatus() async {
  final doc = await FirebaseFirestore.instance
      .collection('follows')
      .doc('${currentStudentId}_${teacherId}')
      .get();

  setState(() {
    isFollowing = doc.exists;
  });
}

void toggleFollow() async {
  final docRef = FirebaseFirestore.instance
      .collection('follows')
      .doc('${currentStudentId}_${teacherId}');

  if (isFollowing) {
    await docRef.delete();
  } else {
    await docRef.set({
      'studentId': currentStudentId,
      'teacherId': teacherId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  checkFollowStatus(); // আবার চেক করে স্টেট আপডেট করবে
}
  Future<void> fetchTeacherData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await _firestore.collection('teachers').doc(uid).get();
      if (doc.exists) {
        teacherData = doc.data();
        _nameController.text = teacherData?['name'] ?? '';
        _phoneController.text = teacherData?['phone'] ?? '';
        _locationController.text = teacherData?['currentLocation'] ?? '';
        _classController.text = teacherData?['class'] ?? '';
        _bioController.text = teacherData?['bio'] ?? '';
        gender = teacherData?['gender'];
        selectedSubjects = List<String>.from(teacherData?['subjects'] ?? []);
      }
    } catch (e) {
      print('Error fetching teacher data: $e');
    }

    setState(() => isLoading = false);
  }

  Future<void> updateTeacherProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      String? imageUrl = teacherData?['profileImageUrl'];

      if (_selectedImage != null) {
        final ref = _storage.ref().child('teachers/$uid/profile.jpg');
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      }

      await _firestore.collection('teachers').doc(uid).update({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'currentLocation': _locationController.text,
        'class': _classController.text,
        'bio': _bioController.text,
        'gender': gender,
        'profileImageUrl': imageUrl,
        'subjects': selectedSubjects,
      });
      
ElevatedButton(
  onPressed: () async {
    final List<LatLng>? pickedLocations = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(),
      ),
    );
    
if (pickedLocations != null) {
  setState(() {
    teacherLocations = pickedLocations;
  });
}

    if (pickedLocations != null) {
      setState(() {
        teacherLocations = pickedLocations;
      });
    }
  },
  child: Text('Add Location'),
),
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );

      setState(() {
        isEditing = false;
        _selectedImage = null;
      });

      fetchTeacherData();
    } catch (e) {
      print('Update error: $e');
    }
  }

  Future<void> pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = teacherData?['profileImageUrl'];
    final filteredSubjects = allSubjects.where((subj) {
      final query = _subjectSearchController.text.toLowerCase();
      return subj.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Profile'),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => isEditing = !isEditing),
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : teacherData == null
              ? const Center(child: Text("No profile data found."))
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
                              : photoUrl != null
                                  ? NetworkImage(photoUrl)
                                  : const AssetImage('assets/images/default_avatar.png')
                                      as ImageProvider,
                        ),
                      ),
                      const SizedBox(height: 16),

Align(
  alignment: Alignment.centerLeft,
  child: Text(
    'Bio:',
    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
  ),
),
const SizedBox(height: 4),
Align(
  alignment: Alignment.centerLeft,
  child: Text(
    _bioController.text.isNotEmpty
        ? _bioController.text
        : 'No bio provided.',
    style: TextStyle(fontSize: 15),
  ),
),

const SizedBox(height: 16),

// Student Count (static or dynamic)
FutureBuilder<QuerySnapshot>(
  future: FirebaseFirestore.instance
      .collection('follows')
      .where('teacherId', isEqualTo: _auth.currentUser?.uid)
      .get(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }

    final count = snapshot.data?.docs.length ?? 0;

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Total Students Following: $count',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    );
  },
),

const SizedBox(height: 16),

// Follow Button (student side only)
ElevatedButton.icon(
  onPressed: toggleFollow,
  icon: Icon(
    isFollowing ? Icons.person_remove : Icons.person_add,
    color: Colors.white,
  ),
  label: Text(
    'My Teacher',
    style: TextStyle(color: Colors.white),
  ),
  style: ElevatedButton.styleFrom(
    backgroundColor: isFollowing ? Colors.green : Colors.blueGrey,
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    textStyle: TextStyle(fontSize: 16),
  ),
),
                      buildField('Name', _nameController),
                      buildField('Phone', _phoneController),
                      buildField('Location', _locationController),
                      buildField('Class', _classController),
                      buildField('Bio', _bioController, maxLines: 3),

                      Row(
                        children: [
                          const Text('Gender:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          if (isEditing)
                            DropdownButton<String>(
                              value: gender,
                              hint: const Text("Select"),
                              onChanged: (val) => setState(() => gender = val),
                              items: const [
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                            )
                          else
                            Text(gender ?? 'N/A', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
ElevatedButton.icon(
  onPressed: toggleFollow,
  icon: Icon(
    isFollowing ? Icons.person_remove : Icons.person_add,
    color: Colors.white,
  ),
  label: Text(
    'My Teacher',
    style: TextStyle(color: Colors.white),
  ),
  style: ElevatedButton.styleFrom(
    backgroundColor: isFollowing ? Colors.green : Colors.blueGrey,
  ),
),

                      if (isEditing)
                        TextField(
                          controller: _subjectSearchController,
                          decoration: const InputDecoration(
                            labelText: "Search Subject",
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),

                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Subjects:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8
                        
                        const SizedBox(height: 20),
                        
ElevatedButton.icon(
  icon: const Icon(Icons.videocam),
  label: const Text("Go Live"),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.redAccent,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  ),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateLiveClassScreen()),
    );
  },
),
const SizedBox(height: 24),

ElevatedButton.icon(
  icon: const Icon(Icons.schedule),
  label: const Text("Fee Reminder"),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.teal,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  ),
  onPressed: () {
    final teacherId = FirebaseAuth.instance.currentUser!.uid;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFeeReminderScreen(teacherId: teacherId),
      ),
    );
  },
),