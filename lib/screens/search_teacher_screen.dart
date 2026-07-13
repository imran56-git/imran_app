import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'teacher_profile_screen.dart';

class TeacherSearchScreen extends StatefulWidget {
  const TeacherSearchScreen({super.key});

  @override
  State<TeacherSearchScreen> createState() => _TeacherSearchScreenState();
}

class _TeacherSearchScreenState extends State<TeacherSearchScreen> {
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();

  List<DocumentSnapshot> searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _uidController.dispose();
    _nameController.dispose();
    _subjectController.dispose();
    _locationController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  void _searchTeachers() async {
    setState(() => _isSearching = true);

    final String uidInput = _uidController.text.trim();
    final String nameInput = _nameController.text.trim();
    final String subjectInput = _subjectController.text.trim();
    final String locationInput = _locationController.text.trim();
    final String expInput = _experienceController.text.trim();

    try {
      if (uidInput.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('teachers').doc(uidInput).get();
        setState(() {
          searchResults = doc.exists ? [doc] : [];
          _isSearching = false;
        });
        return;
      }

      Query query = FirebaseFirestore.instance.collection('teachers');

      if (nameInput.isNotEmpty) {
        query = query.where('name', isEqualTo: nameInput);
      }
      if (locationInput.isNotEmpty) {
        query = query.where('location', isEqualTo: locationInput);
      }
      if (subjectInput.isNotEmpty) {
        query = query.where('subjects', arrayContains: subjectInput);
      }
      if (expInput.isNotEmpty) {
        final exp = int.tryParse(expInput);
        if (exp != null) {
          query = query.where('experience', isGreaterThanOrEqualTo: exp);
        }
      }

      final snapshot = await query.get();
      setState(() {
        searchResults = snapshot.docs;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        debugPrint("Firestore Search Exception: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Search failed. Ensure Compound Indexes are built in Firebase Console."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _clearFilters() {
    _uidController.clear();
    _nameController.clear();
    _subjectController.clear();
    _locationController.clear();
    _experienceController.clear();
    setState(() {
      searchResults.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.school_rounded, color: Color(0xFF1E4C7A), size: 30),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'FYBTT', 
              style: TextStyle(
                color: Color(0xFF1E4C7A), 
                fontWeight: FontWeight.black, 
                fontSize: 19, 
                letterSpacing: 0.5
              )
            ),
          ],
        ),
        actions: [
          if (searchResults.isNotEmpty || 
              _uidController.text.isNotEmpty || 
              _nameController.text.isNotEmpty || 
              _subjectController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E4C7A)),
              onPressed: _clearFilters,
              tooltip: "Clear Filters",
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildAdvancedSearchPanel(),
                    _isSearching
                        ? const Padding(
                            padding: EdgeInsets.only(top: 60),
                            child: Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A), strokeWidth: 3.5)),
                          )
                        : searchResults.isEmpty
                            ? _buildNoResultsView()
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: searchResults.length,
                                itemBuilder: (context, index) =>
                                    _buildTeacherCard(searchResults[index]),
                              ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSearchPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 15, 24, 25),
      decoration: const BoxDecoration(
        color: Color(0xFF1E4C7A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              "Find Your Best Teacher",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 20),

          _customSearchField(
            "Search by Teacher UID / Registration ID",
            _uidController,
            Icons.vpn_key_outlined,
          ),
          const SizedBox(height: 12),

          const Row(
            children: [
              Expanded(child: Divider(color: Colors.white24, thickness: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text("OR USE FILTERS", style: TextStyle(color: Colors.white64, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
              Expanded(child: Divider(color: Colors.white24, thickness: 1)),
            ],
          ),
          const SizedBox(height: 12),

          _customSearchField(
            "Teacher's Name",
            _nameController,
            Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _customSearchField(
                  "Subject",
                  _subjectController,
                  Icons.book_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _customSearchField(
                  "Location",
                  _locationController,
                  Icons.location_on_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _customSearchField(
            "Minimum Experience (Years)",
            _experienceController,
            Icons.history_toggle_off_rounded,
            isNumber: true,
          ),
          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                _searchTeachers();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 1,
              ),
              child: const Text(
                "SEARCH TEACHERS",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customSearchField(
    String hint,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB300), size: 22),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _buildTeacherCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final String teacherName = data['name'] ?? data['displayName'] ?? 'No Name Provided';
    final String location = data['location'] ?? 'Location N/A';
    final int experience = data['experience'] is int 
        ? data['experience'] 
        : (int.tryParse(data['experience']?.toString() ?? '0') ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E4C7A).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.transparent,
                child: Icon(Icons.person_rounded, size: 32, color: Color(0xFF1E4C7A)),
              ),
            ),
            title: Text(
              teacherName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1B1B1B)),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "$location • $experience Years Exp.", 
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherProfileScreen(currentUserId: doc.id),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E4C7A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text("View Full Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 75, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "No teachers match your search.", 
              style: TextStyle(fontSize: 15, color: Colors.grey.shade500, fontWeight: FontWeight.w600)
            ),
          ],
        ),
      ),
    );
  }
}
