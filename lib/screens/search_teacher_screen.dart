import 'package:flutter/material.dart';
import 'teacher_search_result_screen.dart';

class TeacherSearchScreen extends StatefulWidget {
  const TeacherSearchScreen({super.key});

  @override
  State<TeacherSearchScreen> createState() => _TeacherSearchScreenState();
}

class _TeacherSearchScreenState extends State<TeacherSearchScreen> {
  late final TextEditingController _uidController;
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _locationController;
  late final TextEditingController _experienceController;

  String _selectedRadiusRange = '1–10 KM';
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
    _uidController = TextEditingController();
    _nameController = TextEditingController();
    _subjectController = TextEditingController();
    _locationController = TextEditingController();
    _experienceController = TextEditingController();

    _uidController.addListener(_validateSearchForm);
    _nameController.addListener(_validateSearchForm);
    _subjectController.addListener(_validateSearchForm);
    _locationController.addListener(_validateSearchForm);
    _experienceController.addListener(_validateSearchForm);
  }

  @override
  void dispose() {
    _uidController.dispose();
    _nameController.dispose();
    _subjectController.dispose();
    _locationController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  void _validateSearchForm() {
    final bool hasInput = _uidController.text.trim().isNotEmpty ||
        _nameController.text.trim().isNotEmpty ||
        _subjectController.text.trim().isNotEmpty ||
        _locationController.text.trim().isNotEmpty ||
        _experienceController.text.trim().isNotEmpty;

    if (_isSearchButtonEnabled != hasInput) {
      setState(() {
        _isSearchButtonEnabled = hasInput;
      });
    }
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
      debugPrint("Parsing exception for radius: $e");
    }
    return {'min': 1.0, 'max': 10.0};
  }

  void _clearFilters() {
    _uidController.clear();
    _nameController.clear();
    _subjectController.clear();
    _locationController.clear();
    _experienceController.clear();
    setState(() {
      _selectedRadiusRange = '1–10 KM';
      _isSearchButtonEnabled = false;
    });
  }

  void _navigateToResults() {
    FocusScope.of(context).unfocus();

    final String targetUid = _uidController.text.trim();
    final Map<String, dynamic> searchFilters;

    if (targetUid.isNotEmpty) {
      searchFilters = {
        'teacherId': targetUid,
        'name': '',
        'subject': '',
        'location': '',
        'experience': '',
        'minRadius': null,
        'maxRadius': null,
      };
    } else {
      final radiusLimits = _parseRadiusRange(_selectedRadiusRange);
      searchFilters = {
        'teacherId': '',
        'name': _nameController.text.trim(),
        'subject': _subjectController.text.trim(),
        'location': _locationController.text.trim(),
        'experience': _experienceController.text.trim(),
        'minRadius': radiusLimits['min'],
        'maxRadius': radiusLimits['max'],
      };
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherSearchResultScreen(filters: searchFilters),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Find Your Teacher',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E4C7A),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_isSearchButtonEnabled || _selectedRadiusRange != '1–10 KM' || _experienceController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildAdvancedSearchPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSearchPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            "Search Directly by Teacher ID",
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          _customSearchField("Enter Teacher Unique ID", _uidController, Icons.tag_rounded),
          
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.2), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "OR SEARCH BY FILTERS",
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.2), thickness: 1)),
            ],
          ),
          const SizedBox(height: 16),
          
          _customSearchField("Teacher's Name", _nameController, Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _customSearchField("Subject (e.g. Physics, Chemistry)", _subjectController, Icons.book_outlined),
          const SizedBox(height: 12),
          _customSearchField("Location / Area", _locationController, Icons.location_on_outlined),
          const SizedBox(height: 12),
          _customSearchField("Minimum Experience (Years)", _experienceController, Icons.history_toggle_off_rounded, isNumber: true),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.radar_rounded, color: Color(0xFFFFB300), size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Search Radius",
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(
                  width: 135,
                  child: _buildCustomDropdown(
                    value: _selectedRadiusRange,
                    items: _radiusOptions,
                    onChanged: (val) => setState(() => _selectedRadiusRange = val ?? '1–10 KM'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),

          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSearchButtonEnabled ? const Color(0xFFFFB300) : Colors.grey.shade400,
                foregroundColor: _isSearchButtonEnabled ? const Color(0xFF0F172A) : Colors.white24,
                disabledBackgroundColor: Colors.grey.shade400,
                disabledForegroundColor: Colors.white60,
                elevation: _isSearchButtonEnabled ? 4 : 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isSearchButtonEnabled ? _navigateToResults : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSearchButtonEnabled ? Icons.search_rounded : Icons.search_off_rounded, 
                    size: 20, 
                    color: _isSearchButtonEnabled ? const Color(0xFF0F172A) : Colors.white60
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Search Teachers", 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 15, 
                      color: _isSearchButtonEnabled ? const Color(0xFF0F172A) : Colors.white60,
                      letterSpacing: 0.3
                    )
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
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF1E4C7A),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFFFB300), size: 24),
        items: items.map((String val) {
          return DropdownMenuItem<String>(
            value: val, 
            child: Text(val, overflow: TextOverflow.ellipsis)
          );
        }).toList(),
        onChanged: onChanged,
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
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), 
          borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.5)
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }
}
