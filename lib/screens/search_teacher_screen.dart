import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'teacher_profile_screen.dart'; // <-- Add this import if not already

class TeacherSearchScreen extends StatefulWidget {
  const TeacherSearchScreen({super.key});

  @override
  State<TeacherSearchScreen> createState() => _TeacherSearchScreenState();
}

class _TeacherSearchScreenState extends State<TeacherSearchScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();

  List<Map<String, dynamic>> searchResults = [];
  List<String> teacherIds = []; // <-- New: to store document IDs

  void _searchTeachers() async {
    Query query = FirebaseFirestore.instance.collection('teachers');

    if (_nameController.text.trim().isNotEmpty) {
      query = query.where('name', isEqualTo: _nameController.text.trim());
    }
    if (_subjectController.text.trim().isNotEmpty) {
      query = query.where('subjects', arrayContains: _subjectController.text.trim());
    }
    if (_locationController.text.trim().isNotEmpty) {
      query = query.where('location', isEqualTo: _locationController.text.trim());
    }
    if (_experienceController.text.trim().isNotEmpty) {
      final exp = int.tryParse(_experienceController.text.trim());
      if (exp != null) {
        query = query.where('experience', isGreaterThanOrEqualTo: exp);
      }
    }

    final snapshot = await query.get();
    setState(() {
      searchResults = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      teacherIds = snapshot.docs.map((doc) => doc.id).toList(); // <-- New
    });
  }

  Widget _buildSearchField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> data, int index) {
    return Card(
      child: ListTile(
        title: Text(data['name'] ?? 'Unnamed'),
        subtitle: Text(
            'Subject: ${data['subjects']?.join(', ') ?? 'N/A'}\nLocation: ${data['location'] ?? 'N/A'}\nExperience: ${data['experience'] ?? 0} years'),
        trailing: const Icon(Icons.chat),
        onTap: () {
          final teacherId = teacherIds[index]; // <-- New
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherProfileScreen(teacherId: teacherId),
            ),
          );
        },
      ),
    );
  }

  @override
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Teachers')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchField('Name', _nameController),
            _buildSearchField('Subject', _subjectController),
            _buildSearchField('Location', _locationController),
            _buildSearchField('Minimum Experience (years)', _experienceController),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text("Search"),
              onPressed: _searchTeachers,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: searchResults.isEmpty
                  ? const Text("No results found.")
                  : ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) =>
                          _buildResultCard(searchResults[index], index),
                    ),
            )
          ],
        ),
      ),
    );
  }
}