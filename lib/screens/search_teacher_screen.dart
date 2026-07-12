import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'teacher_profile_screen.dart';

class TeacherSearchScreen extends StatefulWidget {
  const TeacherSearchScreen({super.key});

  @override
  State<TeacherSearchScreen> createState() => _TeacherSearchScreenState();
}

class _TeacherSearchScreenState extends State<TeacherSearchScreen> {
  // কন্ট্রোলারস (UID সার্চ ফিল্ড সহ)
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();

  List<DocumentSnapshot> searchResults = [];
  bool _isSearching = false;

  // ডাইনামিক সার্চ ফাংশন
  void _searchTeachers() async {
    setState(() => _isSearching = true);
    
    final String uidInput = _uidController.text.trim();
    final String nameInput = _nameController.text.trim();
    final String subjectInput = _subjectController.text.trim();
    final String locationInput = _locationController.text.trim();
    final String expInput = _experienceController.text.trim();

    try {
      // বাগ ১৪ ফিক্স: ইউজার যদি UID/Reg ID দিয়ে সার্চ করতে চায়, তবে সরাসরি ডকুমেন্ট গেট হবে (সবচেয়ে ফাস্ট ও ইনডেক্স মুক্ত)
      if (uidInput.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('teachers').doc(uidInput).get();
        setState(() {
          searchResults = doc.exists ? [doc] : [];
          _isSearching = false;
        });
        return;
      }

      // অন্যথায় মাল্টিপল ক্রাইটেরিয়া অনুযায়ী কুয়েরি বিল্ড হবে
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
        // ফায়ারবেস ইনডেক্স এরর বা অন্য কোনো প্রবলেম কনসোলে প্রপারলি ট্র্যাক করার জন্য
        debugPrint("Firestore Search Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Search failed: Please check indexing or inputs."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // সার্চ ফিল্ড ক্লিয়ার করার অপশন
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.school, color: Color(0xFF1A237E), size: 32),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'FYBTT', 
              style: TextStyle(
                color: Colors.black, 
                fontWeight: FontWeight.bold, 
                fontSize: 18, 
                letterSpacing: 0.5
              )
            ),
          ],
        ),
        actions: [
          if (searchResults.isNotEmpty || _uidController.text.isNotEmpty || _nameController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _clearFilters,
              tooltip: "Clear Filters",
            )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  children: [
                    _buildAdvancedSearchPanel(),
                    _isSearching
                        ? const Padding(
                            padding: EdgeInsets.only(top: 50),
                            child: Center(child: CircularProgressIndicator(color: Color(0xFF1A237E))),
                          )
                        : searchResults.isEmpty
                            ? _buildNoResultsView()
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                shrinkWrap: true, // Scroll衝突 এড়ানোর জন্য
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
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A237E),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const Center(
            child: Text(
              "Find Your Teacher",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // বাগ ১৪ ফিক্স: Firebase UID / Registration ID সার্চ ইনপুট
          _customSearchField(
            "Search by Firebase UID / Reg ID",
            _uidController,
            Icons.vpn_key_outlined,
          ),
          const SizedBox(height: 10),
          
          const Row(
            children: [
              Expanded(child: Divider(color: Colors.white24, thickness: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text("OR USE FILTERS", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              Expanded(child: Divider(color: Colors.white24, thickness: 1)),
            ],
          ),
          const SizedBox(height: 10),

          _customSearchField(
            "Teacher's Name",
            _nameController,
            Icons.person_outline,
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
              const SizedBox(width: 10),
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
            "Min. Experience (Years)",
            _experienceController,
            Icons.history,
            isNumber: true,
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                FocusScope.of(context).unfocus(); // সার্চের সময় কিবোর্ড ডাউন করা
                _searchTeachers();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 2,
              ),
              child: const Text(
                "SEARCH TEACHERS",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB300)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildTeacherCard(DocumentSnapshot doc) {
    // সেফ টাইপ কাস্টিং
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // বাগ ১৫ ফিক্স: মাল্টিপল ফিল্ড চেক যাতে নাম কোন অবস্থাতেই "Unknown" না আসে
    final String teacherName = data['name'] ?? data['displayName'] ?? 'No Name Provided';
    final String location = data['location'] ?? 'Location N/A';
    final int experience = data['experience'] is int ? data['experience'] : (int.tryParse(data['experience']?.toString() ?? '0') ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.indigo.shade50,
              child: const Icon(Icons.person, size: 35, color: Color(0xFF1A237E)),
            ),
            title: Text(
              teacherName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blackDE),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text("$location • $experience Years Exp.", style: TextStyle(color: Colors.grey.shade600)),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherProfileScreen(teacherId: doc.id),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("View Profile", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 15),
            Text(
              "No teachers found.", 
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)
            ),
          ],
        ),
      ),
    );
  }
}
