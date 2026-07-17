import 'package:flutter/material.dart';
import 'teacher_search_result_screen.dart'; // Navigates to dedicated result screen

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

  String _selectedRadius = '10 KM'; // Default 10 KM as requested
  bool _isSearchButtonEnabled = false;

  final List<String> _radiusOptions = [
    '10 KM',
    '20 KM',
    '30 KM',
    '40 KM',
    '50 KM'
  ];

  @override
  void initState() {
    super.initState();
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

  /// Strict Validation Logic: Enabled ONLY when Teacher ID OR Name OR Subject OR Location is filled
  void _validateSearchForm() {
    final bool hasRequiredInput = _uidController.text.trim().isNotEmpty ||
        _nameController.text.trim().isNotEmpty ||
        _subjectController.text.trim().isNotEmpty ||
        _locationController.text.trim().isNotEmpty;

    if (_isSearchButtonEnabled != hasRequiredInput) {
      setState(() {
        _isSearchButtonEnabled = hasRequiredInput;
      });
    }
  }

  void _clearFilters() {
    _uidController.clear();
    _nameController.clear();
    _subjectController.clear();
    _locationController.clear();
    _experienceController.clear();
    setState(() {
      _selectedRadius = '10 KM';
      _isSearchButtonEnabled = false;
    });
  }

  void _navigateToResults() {
    FocusScope.of(context).unfocus();
    
    // Extracted clean filtering parameters
    final Map<String, dynamic> searchFilters = {
      'teacherId': _uidController.text.trim(),
      'name': _nameController.text.trim(),
      'subject': _subjectController.text.trim(),
      'location': _locationController.text.trim(),
      'experience': _experienceController.text.trim(),
      'radius': double.parse(_selectedRadius.replaceAll(' KM', '')),
    };

    // Navigates directly to the results screen instead of showing it inline
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
          if (_isSearchButtonEnabled || _selectedRadius != '10 KM' || _experienceController.text.isNotEmpty)
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
          /* 
             DUPLICATE LOGO FIX:
             Removed the second secondary 'FYBTT' text row widget from here 
             as it's already rendered cleanly by the native AppBar above.
          */
          const Text(
            "Configure Filters to Match Teachers",
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          _customSearchField("Search by Teacher ID", _uidController, Icons.tag_rounded),
          const SizedBox(height: 12),
          _customSearchField("Teacher's Name", _nameController, Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _customSearchField("Subject (e.g. Physics, Chemistry)", _subjectController, Icons.book_outlined),
          const SizedBox(height: 12),
          _customSearchField("Location / Area", _locationController, Icons.location_on_outlined),
          const SizedBox(height: 12),
          _customSearchField("Minimum Experience (Years)", _experienceController, Icons.history_toggle_off_rounded, isNumber: true),
          const SizedBox(height: 16),
          
          // Modern Radius Selection Card Row
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
                  width: 110,
                  child: _buildCustomDropdown(
                    value: _selectedRadius,
                    items: _radiusOptions,
                    onChanged: (val) => setState(() => _selectedRadius = val ?? '10 KM'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Validation-Driven Dynamic Search Button (Grey/Disabled vs Yellow/Enabled)
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