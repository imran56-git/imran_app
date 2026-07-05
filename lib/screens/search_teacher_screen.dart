import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'teacher_profile_screen.dart';

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

  List<DocumentSnapshot> searchResults = [];
  bool _isSearching = false;

  void _searchTeachers() async {
    setState(() => _isSearching = true);
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
      if (exp != null) query = query.where('experience', isGreaterThanOrEqualTo: exp);
    }

    try {
      final snapshot = await query.get();
      setState(() {
        searchResults = snapshot.docs;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error fetching data.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Find Your Teacher", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildAdvancedSearchPanel(),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
                : searchResults.isEmpty
                    ? _buildNoResultsView()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) => _buildTeacherCard(searchResults[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSearchPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A237E),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          _customSearchField("Teacher's Name", _nameController, Icons.person_outline),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _customSearchField("Subject", _subjectController, Icons.book_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _customSearchField("Location", _locationController, Icons.location_on_outlined)),
          ]),
          const SizedBox(height: 12),
          _customSearchField("Min. Experience (Years)", _experienceController, Icons.history, isNumber: true),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _searchTeachers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("SEARCH TEACHERS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
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
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB300)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildTeacherCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(radius: 30, backgroundColor: Colors.indigo.shade50, child: const Icon(Icons.person, size: 35, color: Color(0xFF1A237E))),
            title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text("${data['location']} • ${data['experience']} Years Exp."),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherProfileScreen(teacherId: doc.id))),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("View Profile", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 80, color: Colors.grey), const Text("No teachers found.")]);
  }
}
