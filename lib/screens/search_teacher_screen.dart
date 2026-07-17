import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/teacher_card_widget.dart';

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
  final TextEditingController _classController = TextEditingController();

  String _selectedGender = 'All';
  String _selectedMode = 'All'; 
  String _selectedRadiusRange = '1–10 KM';

  final double _studentLat = 22.5726; 
  final double _studentLng = 88.3639;

  bool _isSearchButtonEnabled = false;

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

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0; 

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
    return {'min': 0.0, 'max': 10.0}; 
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

                  final uidQ = _uidController.text.trim().toLowerCase();
                  final nameQ = _nameController.text.trim().toLowerCase();
                  final locQ = _locationController.text.trim().toLowerCase();
                  final subQ = _subjectController.text.trim().toLowerCase();
                  final classQ = _classController.text.trim().toLowerCase();
                  final expQ = _experienceController.text.trim();

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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>? ?? {};

                    double tLat = double.tryParse(data['latitude']?.toString() ?? '0.0') ?? 0.0;
                    double tLng = double.tryParse(data['longitude']?.toString() ?? '0.0') ?? 0.0;
                    double distance = _calculateHaversineDistance(_studentLat, _studentLng, tLat, tLng);

                    final List subjectsList = data['subjects'] is List ? data['subjects'] : [];
                    final String subjectText = subjectsList.isNotEmpty ? subjectsList.join(', ') : 'General';

                    return TeacherCardWidget(
                      teacherId: doc.id,
                      name: data['name'] ?? data['displayName'] ?? 'No Name',
                      subject: subjectText,
                      profileImageUrl: data['photoUrl'] ?? '',
                      latitude: tLat,
                      longitude: tLng,
                      studentCount: data['studentCount'] is int ? data['studentCount'] : 0,
                      experienceYears: data['experience'] is int ? data['experience'] : 0,
                      followersCount: data['followersCount'] is int ? data['followersCount'] : 0,
                      rating: double.tryParse(data['rating']?.toString() ?? '5.0') ?? 5.0,
                      locationText: data['location'] ?? 'Location N/A',
                      calculatedDistance: "${distance.toStringAsFixed(1)} KM",
                      onChatPressed: () {},
                    );
                  },
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
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
              if (_isSearchButtonEnabled || _selectedGender != 'All' || _selectedMode != 'All' || _selectedRadiusRange != '1–10 KM')
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                  onPressed: _clearFilters,
                  visualDensity: VisualDensity.compact,
                ),
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
              Expanded(
                child: _buildCustomDropdown(
                  value: _selectedGender,
                  items: ['All', 'Male', 'Female'],
                  onChanged: (val) => setState(() => _selectedGender = val ?? 'All'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCustomDropdown(
                  value: _selectedMode,
                  items: ['All', 'Online', 'Offline'],
                  onChanged: (val) => setState(() => _selectedMode = val ?? 'All'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.radar_rounded, color: Color(0xFFFFB300), size: 18),
              const SizedBox(width: 8),
              const Text(
                "Search Radius:",
                style: TextStyle(color: Colors.whiteFE ?? Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSearchButtonEnabled ? const Color(0xFFFFB300) : Colors.grey.shade400,
                foregroundColor: _isSearchButtonEnabled ? const Color(0xFF0F172A) : Colors.white,
                elevation: _isSearchButtonEnabled ? 4 : 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSearchButtonEnabled ? () {
                FocusScope.of(context).unfocus();
              } : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isSearchButtonEnabled ? Icons.search_rounded : Icons.search_off_rounded, size: 20),
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
