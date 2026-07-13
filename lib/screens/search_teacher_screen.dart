import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'teacher_profile_screen.dart';
import 'teaching_areas_map_screen.dart'; // নতুন ক্রিয়েট করা ম্যাপ স্ক্রিন

class TeacherSearchScreen extends StatefulWidget {
  const TeacherSearchScreen({super.key});

  @override
  State<TeacherSearchScreen> createState() => _TeacherSearchScreenState();
}

class _TeacherSearchScreenState extends State<TeacherSearchScreen> {
  // টেক্সট কন্ট্রোলারসমূহ
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _classController = TextEditingController();

  // ফিল্টার স্ট্যাটাস ভেরিয়েবল
  String _selectedGender = 'All';
  String _selectedMode = 'All'; // All, Online, Offline

  List<DocumentSnapshot> searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _uidController.dispose();
    _nameController.dispose();
    _subjectController.dispose();
    _locationController.dispose();
    _experienceController.dispose();
    _classController.dispose();
    super.dispose();
  }

  void _searchTeachers() async {
    setState(() => _isSearching = true);

    final String uidInput = _uidController.text.trim();
    final String nameInput = _nameController.text.trim().toLowerCase();
    final String subjectInput = _subjectController.text.trim().toLowerCase();
    final String locationInput = _locationController.text.trim().toLowerCase();
    final String classInput = _classController.text.trim().toLowerCase();
    final String expInput = _experienceController.text.trim();

    try {
      // যদি UID দিয়ে সার্চ করা হয় (Direct Document Fetch)
      if (uidInput.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('teachers').doc(uidInput).get();
        setState(() {
          searchResults = doc.exists ? [doc] : [];
          _isSearching = false;
        });
        return;
      }

      // সাধারণ ফিল্টার কোয়েরি বেস
      Query query = FirebaseFirestore.instance.collection('teachers');

      // Firebase Compound Indexing অপ্টিমাইজড ফিল্টারিং
      if (_selectedGender != 'All') {
        query = query.where('gender', isEqualTo: _selectedGender);
      }
      if (_selectedMode != 'All') {
        query = query.where('teachingMode', isEqualTo: _selectedMode);
      }

      final snapshot = await query.get();
      List<DocumentSnapshot> filteredDocs = snapshot.docs;

      // ক্লায়েন্ট-সাইড অ্যাডভান্সড টেক্সট ফিল্টারিং (যা Index Crash এড়াবে এবং সুপারফাস্ট রেসপন্স দেবে)
      if (nameInput.isNotEmpty || subjectInput.isNotEmpty || locationInput.isNotEmpty || classInput.isNotEmpty || expInput.isNotEmpty) {
        filteredDocs = filteredDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          
          final name = (data['name'] ?? '').toString().toLowerCase();
          final location = (data['location'] ?? '').toString().toLowerCase();
          final List subjects = data['subjects'] is List ? data['subjects'] : [];
          final List classes = data['classes'] is List ? data['classes'] : [];
          final int exp = data['experience'] is int ? data['experience'] : (int.tryParse(data['experience']?.toString() ?? '0') ?? 0);

          bool matchesName = nameInput.isEmpty || name.contains(nameInput);
          bool matchesLocation = locationInput.isEmpty || location.contains(locationInput);
          bool matchesSubject = subjectInput.isEmpty || subjects.any((s) => s.toString().toLowerCase().contains(subjectInput));
          bool matchesClass = classInput.isEmpty || classes.any((c) => c.toString().toLowerCase().contains(classInput));
          
          bool matchesExp = true;
          if (expInput.isNotEmpty) {
            final targetExp = int.tryParse(expInput);
            if (targetExp != null) {
              matchesExp = exp >= targetExp;
            }
          }

          return matchesName && matchesLocation && matchesSubject && matchesClass && matchesExp;
        }).toList();
      }

      setState(() {
        searchResults = filteredDocs;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        debugPrint("Firestore Search Exception: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Search failed. Something went wrong!"),
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
    _classController.clear();
    setState(() {
      _selectedGender = 'All';
      _selectedMode = 'All';
      searchResults.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildAdvancedSearchPanel(),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A), strokeWidth: 3.5))
                  : searchResults.isEmpty
                      ? _buildNoResultsView()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) => _buildTeacherCard(searchResults[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSearchPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E4C7A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ব্র্যান্ডিং হেডার এবং ক্লিয়ার ফিল্টার আইকন সিঙ্ক
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.school_rounded, color: Color(0xFFFFB300), size: 28),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'FYBTT • Find Teacher',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.3),
                  ),
                ],
              ),
              if (searchResults.isNotEmpty || _uidController.text.isNotEmpty || _nameController.text.isNotEmpty)
                GestureDetector(
                  onTap: _clearFilters,
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                  ),
                )
            ],
          ),
          const SizedBox(height: 16),

          _customSearchField("Search by Teacher UID / Registration ID", _uidController, Icons.vpn_key_outlined),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: _customSearchField("Teacher's Name", _nameController, Icons.person_outline_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _customSearchField("Subject", _subjectController, Icons.book_outlined)),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: _customSearchField("Location / Area", _locationController, Icons.location_on_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _customSearchField("Class (e.g. 10, 12)", _classController, Icons.class_outlined)),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: _customSearchField("Min Exp (Years)", _experienceController, Icons.history_toggle_off_rounded, isNumber: true)),
              const SizedBox(width: 10),
              // জেন্ডার ড্রপডাউন
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGender,
                      dropdownColor: const Color(0xFF1E4C7A),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFB300)),
                      items: <String>['All', 'Male', 'Female'].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedGender = val ?? 'All'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // অনলাইন/অফলাইন মোড ড্রপডাউন
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMode,
                      dropdownColor: const Color(0xFF1E4C7A),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFB300)),
                      items: <String>['All', 'Online', 'Offline'].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedMode = val ?? 'All'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.withAnimation(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () {
                FocusScope.of(context).unfocus();
                _searchTeachers();
              },
              child: const Text("SEARCH TEACHERS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
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
      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB300), size: 18),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }

  Widget _buildTeacherCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final String teacherName = data['name'] ?? data['displayName'] ?? 'No Name';
    final String location = data['location'] ?? 'Location N/A';
    final String photoUrl = data['photoUrl'] ?? '';
    final int experience = data['experience'] is int ? data['experience'] : (int.tryParse(data['experience']?.toString() ?? '0') ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF1E4C7A).withOpacity(0.1),
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty ? const Icon(Icons.person_rounded, size: 28, color: Color(0xFF1E4C7A)) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            teacherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B1B1B)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.map_rounded, color: Colors.teal, size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeachingAreasMapScreen(
                                  teacherId: doc.id,
                                  teacherName: teacherName,
                                ),
                              ),
                            );
                          },
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$location • $experience Years Exp.",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1E4C7A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TeacherProfileScreen(currentUserId: doc.id)),
                      );
                    },
                    child: const Text("View Profile", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E4C7A), fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006653),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      // চ্যাট সিস্টেমে ডিরেক্ট ন্যাভিগেশন লজিক
                    },
                    child: const Text("Chat Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text("No teachers match your search.", style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// এক্সটেনশন মেথড ফর বাটন অ্যানিমেশন সাপোর্ট
extension on ElevatedButton {
  static Widget withAnimation({required ButtonStyle style, required VoidCallback onPressed, required Widget child}) {
    return ElevatedButton(style: style, onPressed: onPressed, child: child);
  }
}
