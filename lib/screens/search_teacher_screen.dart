import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'teacher_profile_screen.dart'; 
// import 'google_map_screen.dart'; // Ensure this file exists for navigation

class TeacherSearchScreen extends StatefulWidget {
  const TeacherSearchScreen({super.key});

  @override
  State<TeacherSearchScreen> createState() => _TeacherSearchScreenState();
}

class _TeacherSearchScreenState extends State<TeacherSearchScreen> {
  // Controllers for all features you requested
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();

  List<DocumentSnapshot> searchResults = [];
  bool _isSearching = false;

  // Optimized Search Logic
  void _searchTeachers() async {
    setState(() => _isSearching = true);
    
    Query query = FirebaseFirestore.instance.collection('teachers');

    // Name Filter
    if (_nameController.text.trim().isNotEmpty) {
      query = query.where('name', isEqualTo: _nameController.text.trim());
    }
    // Subject Filter (Array check)
    if (_subjectController.text.trim().isNotEmpty) {
      query = query.where('subjects', arrayContains: _subjectController.text.trim());
    }
    // Location Filter
    if (_locationController.text.trim().isNotEmpty) {
      query = query.where('location', isEqualTo: _locationController.text.trim());
    }
    // Experience Filter (The feature you almost missed!)
    if (_experienceController.text.trim().isNotEmpty) {
      final exp = int.tryParse(_experienceController.text.trim());
      if (exp != null) {
        query = query.where('experience', isGreaterThanOrEqualTo: exp);
      }
    }

    try {
      final snapshot = await query.get();
      setState(() {
        searchResults = snapshot.docs;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Search error: Please check your internet or Firestore indexes.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Find Your Teacher", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildAdvancedSearchPanel(),
          Expanded(
            child: _isSearching 
              ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
              : searchResults.isEmpty 
                ? _buildNoResultsView()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final data = searchResults[index].data() as Map<String, dynamic>;
                      final docId = searchResults[index].id;
                      return _buildProfessionalTeacherCard(data, docId);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSearchPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: Colors.indigo[800],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          _customSearchField("Teacher's Name", _nameController, Icons.person_search),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _customSearchField("Subject", _subjectController, Icons.book)),
              const SizedBox(width: 10),
              Expanded(child: _customSearchField("Location", _locationController, Icons.map)),
            ],
          ),
          const SizedBox(height: 10),
          _customSearchField("Min. Experience (Years)", _experienceController, Icons.history_edu, isNumber: true),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _searchTeachers,
              icon: const Icon(Icons.manage_search_rounded, size: 28),
              label: const Text("SEARCH TEACHERS", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customSearchField(String hint, TextEditingController controller, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.orangeAccent, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      ),
    );
  }

  Widget _buildProfessionalTeacherCard(Map<String, dynamic> data, String docId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.indigo[50],
                child: const Icon(Icons.person, color: Colors.indigo, size: 30),
              ),
              title: Text(data['name'] ?? 'Unnamed Teacher', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  "${data['location'] ?? 'Location N/A'} • ${data['experience'] ?? 0} Years Exp.",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
            if (data['subjects'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 0,
                  children: (data['subjects'] as List).map((s) => Chip(
                    label: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    backgroundColor: Colors.orange[50],
                    side: BorderSide(color: Colors.orange[200]!),
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ),
            const Divider(height: 30),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherProfileScreen(teacherId: docId))),
                      icon: const Icon(Icons.badge_outlined, size: 18),
                      label: const Text("PROFILE"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.indigo,
                        side: const BorderSide(color: Colors.indigo),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () { /* Navigate to Map Screen */ },
                      icon: const Icon(Icons.near_me_rounded, size: 18),
                      label: const Text("LOCATION"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("No teachers found.", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const Text("Try changing your search filters.", style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
