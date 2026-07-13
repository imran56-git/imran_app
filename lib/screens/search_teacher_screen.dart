import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'teacher_profile_screen.dart';
import 'teaching_areas_map_screen.dart';

class TeacherSearchScreen extends StatefulWidget {
  const TeacherSearchScreen({super.key});

  @override
  State<TeacherSearchScreen> createState() => _TeacherSearchScreenState();
}

class _TeacherSearchScreenState extends State<TeacherSearchScreen> {
  // টেক্সট কন্ট্রোলারের লিসেনার দিয়ে রিয়াল-টাইম সার্চ ট্র্যাকিং
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _classController = TextEditingController();

  // উন্নত ফিল্টার স্ট্যাটাস ভেরিয়েবল
  String _selectedGender = 'All';
  String _selectedMode = 'All'; // All, Online, Offline

  String _uidQuery = '';
  String _nameQuery = '';
  String _subjectQuery = '';
  String _locationQuery = '';
  String _classQuery = '';
  String _expQuery = '';

  @override
  void initState() {
    super.initState();
    // প্রত্যেকটি ফিল্ডে টাইপিং শুরু করলেই যেন রিয়াল-টাইম আপডেট হয়
    _uidController.addListener(() => setState(() => _uidQuery = _uidController.text.trim().toLowerCase()));
    _nameController.addListener(() => setState(() => _nameQuery = _nameController.text.trim().toLowerCase()));
    _subjectController.addListener(() => setState(() => _subjectQuery = _subjectController.text.trim().toLowerCase()));
    _locationController.addListener(() => setState(() => _locationQuery = _locationController.text.trim().toLowerCase()));
    _classController.addListener(() => setState(() => _classQuery = _classController.text.trim().toLowerCase()));
    _experienceController.addListener(() => setState(() => _expQuery = _experienceController.text.trim()));
  }

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
      _uidQuery = '';
      _nameQuery = '';
      _subjectQuery = '';
      _locationQuery = '';
      _classQuery = '';
      _expQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      // ফিক্সড: ক্লিন এবং একক মেটেরিয়াল ৩ অ্যাপবার (ডুপ্লিকেট লোগো ও হেডার বাফ ফিক্সড)
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E4C7A),
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.school_rounded, color: Color(0xFFFFB300), size: 28),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'FYBTT • Find Teacher',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0.3),
            ),
          ],
        ),
        actions: [
          if (_uidQuery.isNotEmpty || _nameQuery.isNotEmpty || _subjectQuery.isNotEmpty || _locationQuery.isNotEmpty || _selectedGender != 'All' || _selectedMode != 'All')
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _clearFilters,
              tooltip: 'Clear Filters',
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          _buildAdvancedSearchPanel(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('teachers').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1E4C7A), strokeWidth: 3.5));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildNoResultsView();
                }

                // ক্লায়েন্ট-সাইড রিয়াল-টাইম মাল্টি-ফিল্ড ফিল্টারিং ইঞ্জিন (সুপারফাস্ট ও নো-ক্র্যাশ)
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final docId = doc.id.toLowerCase();

                  final name = (data['name'] ?? data['displayName'] ?? '').toString().toLowerCase();
                  final location = (data['location'] ?? '').toString().toLowerCase();
                  final gender = (data['gender'] ?? 'Male').toString();
                  final teachingMode = (data['teachingMode'] ?? 'Offline').toString();
                  final List subjects = data['subjects'] is List ? data['subjects'] : [];
                  final List classes = data['classes'] is List ? data['classes'] : [];
                  final int exp = data['experience'] is int ? data['experience'] : (int.tryParse(data['experience']?.toString() ?? '0') ?? 0);

                  // টেক্সট ফিল্ড কন্ডিশন ম্যাচিং
                  bool matchesUid = _uidQuery.isEmpty || docId.contains(_uidQuery);
                  bool matchesName = _nameQuery.isEmpty || name.contains(_nameQuery);
                  bool matchesLocation = _locationQuery.isEmpty || location.contains(_locationQuery);
                  bool matchesSubject = _subjectQuery.isEmpty || subjects.any((s) => s.toString().toLowerCase().contains(_subjectQuery));
                  bool matchesClass = _classQuery.isEmpty || classes.any((c) => c.toString().toLowerCase().contains(_classQuery));

                  // ড্রপডাউন কন্ডিশন ম্যাচিং
                  bool matchesGender = _selectedGender == 'All' || gender.toLowerCase() == _selectedGender.toLowerCase();
                  bool matchesMode = _selectedMode == 'All' || teachingMode.toLowerCase() == _selectedMode.toLowerCase();

                  // এক্সপেরিয়েন্স কন্ডিশন ম্যাচিং
                  bool matchesExp = true;
                  if (_expQuery.isNotEmpty) {
                    final targetExp = int.tryParse(_expQuery);
                    if (targetExp != null) {
                      matchesExp = exp >= targetExp;
                    }
                  }

                  return matchesUid && matchesName && matchesLocation && matchesSubject && matchesClass && matchesGender && matchesMode && matchesExp;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return _buildNoResultsView();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) => _buildTeacherCard(filteredDocs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSearchPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E4C7A),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
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
              // জেন্ডার ড্রপডাউন ফিল্টার
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGender,
                      dropdownColor: const Color(0xFF1E4C7A),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
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
              // অনলাইন/অফলাইন মোড ড্রপডাউন ফিল্টার
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMode,
                      dropdownColor: const Color(0xFF1E4C7A),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
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
      padding: const EdgeInsets.all(16),
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
              const SizedBox(width: 14),
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
                        // ফিক্সড: নামের পাশে Google Map বাটন সিঙ্ক করা হলো (#10)
                        IconButton(
                          icon: const Icon(Icons.map_rounded, color: Colors.teal, size: 22),
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
                          padding: const EdgeInsets.all(4),
                          tooltip: 'View Teaching Areas',
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
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          // ফিক্সড: বাটন লেআউট সাইজ ও স্টাইল অপ্টিমাইজেশন (#9)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1E4C7A), width: 1.2),
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
                      // চ্যাট সিস্টেমে ডিরেক্ট ন্যাভিগেশন লজিক (ভবিষ্যতের ব্যাকএন্ড হুক)
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
          Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text("No teachers match your search.", style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
