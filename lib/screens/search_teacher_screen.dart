import 'dart:math' as math;
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
  // কন্ট্রোলার সমূহ
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _classController = TextEditingController();

  // ড্রপডাউন ও ফিল্টার স্টেট
  String _selectedGender = 'All';
  String _selectedMode = 'All'; 
  String _selectedRadiusRange = '1–10 KM';

  // স্টুডেন্টের ডামি কারেন্ট লোকেশন (ম্যাপ সার্ভিস তৈরি হলে এটি রিয়েল ডায়নামিক জিপিএস লোকেশন দিয়ে রিপ্লেস হবে)
  final double _studentLat = 22.5726; // উদাহরণ: কলকাতা (Salt Lake এর কাছাকাছি)
  final double _studentLng = 88.3639;

  // সার্চ বাটন একটিভ করার জন্য রিয়েল-টাইম ট্র্যাকিং ভ্যারিয়েবল
  bool _isSearchButtonEnabled = false;

  // রেডিয়াস ফিল্টারের সম্পূর্ণ ভ্যালু লিস্ট (আপনার অর্ডার অনুযায়ী নিখুঁত সাজানো)
  final List<String> _radiusOptions = [
    '1–10 KM', '10–12 KM', '12–14 KM', '14–16 KM', '16–18 KM', '18–20 KM',
    '20–22 KM', '22–24 KM', '24–26 KM', '26–28 KM', '28–30 KM', '30–32 KM',
    '32–34 KM', '34–36 KM', '36–38 KM', '38–40 KM', '40–42 KM', '42–44 KM',
    '44–46 KM', '46–48 KM', '48–50 KM', '50–55 KM', '55–60 KM', '60–65 KM',
    '65–70 KM', '70–75 KM', '75–80 KM', '80–85 KM', '85–90 KM', '90–95 KM',
    '95–100 KM'
  ];

  @override
  void initState() {
    super.initState();
    // প্রতিটি টেক্সট ফিল্ডের ইনপুট মনিটর করার জন্য লিসেনার অ্যাড
    _uidController.addListener(_validateSearchForm);
    _nameController.addListener(_validateSearchForm);
    _subjectController.addListener(_validateSearchForm);
    _locationController.addListener(_validateSearchForm);
    _experienceController.addListener(_validateSearchForm);
    _classController.addListener(_validateSearchForm);
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

  // যেকোনো একটি ফিল্ড পূরণ হলেই সার্চ বাটন এনাবল হবে
  void _validateSearchForm() {
    final bool hasInput = _uidController.text.trim().isNotEmpty ||
        _nameController.text.trim().isNotEmpty ||
        _subjectController.text.trim().isNotEmpty ||
        _locationController.text.trim().isNotEmpty ||
        _experienceController.text.trim().isNotEmpty ||
        _classController.text.trim().isNotEmpty;

    if (_isSearchButtonEnabled != hasInput) {
      setState(() {
        _isSearchButtonEnabled = hasInput;
      });
    }
  }

  // নিখুঁত Haversine ফর্মুলা ব্যবহার করে দুটি কোঅর্ডিনেটের দূরত্ব (KM) বের করার মেথড
  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0; // কিলোমিটার এককে পৃথিবীর ব্যাসার্ধ
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
        
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180.0);
  }

  // ড্রপডাউন রেঞ্জ স্ট্রিং থেকে Min এবং Max KM আলাদা করার পার্সার
  Map<String, double> _parseRadiusRange(String range) {
    try {
      final cleanRange = range.replaceAll(' KM', '');
      final parts = cleanRange.split('–');
      if (parts.length == 2) {
        return {
          'min': double.parse(parts[0].trim()),
          'max': double.parse(parts[1].trim()),
        };
      }
    } catch (e) {
      debugPrint("Radius parsing error: $e");
    }
    return {'min': 0.0, 'max': 10.0}; // ফলব্যাক ডিফল্ট ভ্যালু
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
      _selectedRadiusRange = '1–10 KM';
      _isSearchButtonEnabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.school_rounded, 
                  color: Color(0xFFFFB300), 
                  size: 30
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'FYBTT • Find Teacher',
              style: TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold, 
                fontSize: 18, 
                letterSpacing: 0.5
              ),
            ),
          ],
        ),
        actions: [
          if (_isSearchButtonEnabled || _selectedGender != 'All' || _selectedMode != 'All' || _selectedRadiusRange != '1–10 KM')
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

                // ক্লায়েন্ট সাইড অ্যাডভান্সড ফিল্টারিং
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

                  // কোয়েরি স্ট্রিং প্রিপারেশন (Case-Insensitive)
                  final uidQ = _uidController.text.trim().toLowerCase();
                  final nameQ = _nameController.text.trim().toLowerCase();
                  final locQ = _locationController.text.trim().toLowerCase();
                  final subQ = _subjectController.text.trim().toLowerCase();
                  final classQ = _classController.text.trim().toLowerCase();
                  final expQ = _experienceController.text.trim();

                  // ফিল্টারিং লজিক ম্যাশআপ
                  bool matchesUid = uidQ.isEmpty || docId.contains(uidQ);
                  bool matchesName = nameQ.isEmpty || name.contains(nameQ);
                  bool matchesLocation = locQ.isEmpty || location.contains(locQ);
                  bool matchesSubject = subQ.isEmpty || subjects.any((s) => s.toString().toLowerCase().contains(subQ));
                  bool matchesClass = classQ.isEmpty || classes.any((c) => c.toString().toLowerCase().contains(classQ));
                  bool matchesGender = _selectedGender == 'All' || gender.toLowerCase() == _selectedGender.toLowerCase();
                  bool matchesMode = _selectedMode == 'All' || teachingMode.toLowerCase() == _selectedMode.toLowerCase();

                  bool matchesExp = true;
                  if (expQ.isNotEmpty) {
                    final targetExp = int.tryParse(expQ);
                    if (targetExp != null) {
                      matchesExp = exp >= targetExp;
                    }
                  }

                  // গুগল ল্যাট/লং এর মাধ্যমে একুরেট রেডিয়াস ফিল্টারিং (Haversine)
                  bool matchesRadius = true;
                  if (data.containsKey('latitude') && data.containsKey('longitude')) {
                    double tLat = double.tryParse(data['latitude'].toString()) ?? 0.0;
                    double tLng = double.tryParse(data['longitude'].toString()) ?? 0.0;
                    
                    double distance = _calculateHaversineDistance(_studentLat, _studentLng, tLat, tLng);
                    
                    final radiusLimits = _parseRadiusRange(_selectedRadiusRange);
                    matchesRadius = distance >= radiusLimits['min']! && distance <= radiusLimits['max']!;
                  }

                  return matchesUid && matchesName && matchesLocation && matchesSubject && matchesClass && matchesGender && matchesMode && matchesExp && matchesRadius;
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
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
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
              // জেন্ডার ফিল্টার
              Expanded(
                child: _buildCustomDropdown(
                  value: _selectedGender,
                  items: ['All', 'Male', 'Female'],
                  onChanged: (val) => setState(() => _selectedGender = val ?? 'All'),
                ),
              ),
              const SizedBox(width: 10),
              // মোড ফিল্টার
              Expanded(
                child: _buildCustomDropdown(
                  value: _selectedMode,
                  items: ['All', 'Online', 'Offline'],
                  onChanged: (val) => setState(() => _selectedMode = val ?? 'All'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // নতুন প্রিমিয়াম রেডিয়াস ফিল্টার ড্রপডাউন (Requirement 3)
          Row(
            children: [
              const Icon(Icons.radar_rounded, color: Color(0xFFFFB300), size: 20),
              const SizedBox(width: 8),
              const Text(
                "Search Radius:",
                style: TextStyle(color: Colors.whiteDimmish ?? Colors.whiteEE, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCustomDropdown(
                  value: _selectedRadiusRange,
                  items: _radiusOptions,
                  onChanged: (val) => setState(() => _selectedRadiusRange = val ?? '1–10 KM'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // অ্যানিমেটেড সার্চ বাটন (Requirement 2)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSearchButtonEnabled ? const Color(0xFFFFB300) : Colors.grey.shade400,
                foregroundColor: _isSearchButtonEnabled ? Colors.black87 : Colors.white,
                elevation: _isSearchButtonEnabled ? 4 : 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSearchButtonEnabled ? () {
                // ফর্ম ভ্যালিডেশন হয়ে রিয়েল-টাইম কোয়েরি রিফ্রেশ ট্রিগার করবে
                FocusScope.of(context).unfocus();
              } : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isSearchButtonEnabled ? Icons.search_purple_rounded ?? Icons.search : Icons.search_off_rounded, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    "Search Teachers", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.3)
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomDropdown({required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08), 
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E4C7A),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFFFB300), size: 24),
          items: items.map((String val) {
            return DropdownMenuItem<String>(
              value: val, 
              child: Text(val, overflow: TextOverflow.ellipsis)
            );
          }).toList(),
          onChanged: onChanged,
        ),
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), 
          borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1)
        ),
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
    
    // ডাইনামিক ডিস্ট্যান্স লাইভ ক্যালকুলেশন UI-তে দেখানোর জন্য
    String distanceString = "-- KM";
    if (data.containsKey('latitude') && data.containsKey('longitude')) {
      double tLat = double.tryParse(data['latitude'].toString()) ?? 0.0;
      double tLng = double.tryParse(data['longitude'].toString()) ?? 0.0;
      double distance = _calculateHaversineDistance(_studentLat, _studentLng, tLat, tLng);
      distanceString = "${distance.toStringAsFixed(1)} KM";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Hero(
                tag: 'teacher_avatar_${doc.id}',
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF1E4C7A).withOpacity(0.1),
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty ? const Icon(Icons.person_rounded, size: 30, color: Color(0xFF1E4C7A)) : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            teacherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
     ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)
                          ),
                          child: Text(
                            distanceString,
                            style: const TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1E4C7A), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006653),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      // চ্যাট ন্যাভিগেশন কোড
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
          const SizedBox(height: 14),
          Text(
            "No teachers match your search criteria.", 
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w600)
          ),
        ],
      ),
    );
  }
}