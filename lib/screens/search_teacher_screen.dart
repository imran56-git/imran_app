import 'package:flutter/material.dart';
import '../services/location_service.dart';
import 'location_picker_screen.dart';
import 'teacher_search_result_screen.dart';

enum LocationSearchMode {
  currentGps,
  specificLocation,
}

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

  LocationSearchMode _locationMode = LocationSearchMode.currentGps;
  String _selectedRadius = '25 KM';
  bool _isSearchButtonEnabled = true;
  bool _isFetchingGps = false;

  double? _pickedLatitude;
  double? _pickedLongitude;
  String? _pickedAddress;

  final List<String> _radiusOptions = [
    '5 KM',
    '10 KM',
    '25 KM',
    '50 KM',
    '100 KM',
    'Any Distance',
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
    _validateSearchForm();
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
        _experienceController.text.trim().isNotEmpty ||
        _pickedLatitude != null ||
        _locationMode == LocationSearchMode.currentGps;

    if (_isSearchButtonEnabled != hasInput) {
      setState(() {
        _isSearchButtonEnabled = hasInput;
      });
    }
  }

  double? _parseRadius(String radiusText) {
    if (radiusText == 'Any Distance') return null;
    try {
      final clean = radiusText.replaceAll(' KM', '').trim();
      return double.parse(clean);
    } catch (_) {
      return 25.0;
    }
  }

  void _clearFilters() {
    _uidController.clear();
    _nameController.clear();
    _subjectController.clear();
    _locationController.clear();
    _experienceController.clear();
    setState(() {
      _selectedRadius = '25 KM';
      _locationMode = LocationSearchMode.currentGps;
      _pickedLatitude = null;
      _pickedLongitude = null;
      _pickedAddress = null;
      _isSearchButtonEnabled = true;
    });
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _pickedLatitude,
          initialLongitude: _pickedLongitude,
          initialAddress: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : _pickedAddress,
          isStudentSearchMode: true,
        ),
      ),
    );

    if (result == null) return;

    double? lat;
    double? lng;
    String addr = '';

    if (result is Map<String, dynamic>) {
      lat = (result['latitude'] as num?)?.toDouble();
      lng = (result['longitude'] as num?)?.toDouble();
      addr = (result['address'] ?? result['fullAddress'] ?? '').toString().trim();
    } else if (result is List && result.isNotEmpty) {
      final first = result.first as Map<String, dynamic>;
      lat = (first['latitude'] as num?)?.toDouble();
      lng = (first['longitude'] as num?)?.toDouble();
      addr = (first['fullAddress'] ?? first['address'] ?? '').toString().trim();
    }

    if (lat != null && lng != null) {
      setState(() {
        _pickedLatitude = lat;
        _pickedLongitude = lng;
        _pickedAddress = addr;
        _locationController.text = addr;
        _locationMode = LocationSearchMode.specificLocation;
        _isSearchButtonEnabled = true;
      });
      _validateSearchForm();
      await _navigateToResults();
    }
  }

  Future<void> _navigateToResults() async {
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
        'latitude': null,
        'longitude': null,
        'maxRadius': null,
        'locationMode': 'uid',
      };
    } else {
      double? activeLat = _pickedLatitude;
      double? activeLng = _pickedLongitude;

      if (_locationMode == LocationSearchMode.currentGps) {
        setState(() => _isFetchingGps = true);
        try {
          final pos = await LocationService.getCurrentLocation();
          activeLat = pos.latitude;
          activeLng = pos.longitude;
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not obtain current GPS location. Please check location permissions or enter a specific area.',
                ),
                backgroundColor: Color(0xFFDC2626),
              ),
            );
          }
          setState(() => _isFetchingGps = false);
          return;
        } finally {
          if (mounted) setState(() => _isFetchingGps = false);
        }
      }

      final double? maxRadiusKm = _parseRadius(_selectedRadius);

      searchFilters = {
        'teacherId': '',
        'name': _nameController.text.trim(),
        'subject': _subjectController.text.trim(),
        'location': _locationController.text.trim(),
        'experience': _experienceController.text.trim(),
        'latitude': activeLat,
        'longitude': activeLng,
        'maxRadius': maxRadiusKm,
        'locationMode': _locationMode == LocationSearchMode.currentGps
            ? 'gps'
            : 'specific',
      };
    }

    if (!mounted) return;
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E4C7A),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            tooltip: 'Clear Filters',
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
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Search Directly by Teacher ID",
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _customSearchField(
            "Enter Teacher Unique ID",
            _uidController,
            Icons.tag_rounded,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Colors.white.withOpacity(0.2),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "OR SEARCH BY FILTERS",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: Colors.white.withOpacity(0.2),
                  thickness: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _customSearchField(
            "Teacher's Name",
            _nameController,
            Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),
          _customSearchField(
            "Subject (e.g. Physics, Chemistry, Math)",
            _subjectController,
            Icons.book_outlined,
          ),
          const SizedBox(height: 16),
          const Text(
            "Location Matching Mode",
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _locationMode = LocationSearchMode.currentGps;
                      });
                      _validateSearchForm();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _locationMode == LocationSearchMode.currentGps
                            ? const Color(0xFFFFB300)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: _locationMode == LocationSearchMode.currentGps
                                ? const Color(0xFF0F172A)
                                : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Current GPS",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color:
                                  _locationMode == LocationSearchMode.currentGps
                                      ? const Color(0xFF0F172A)
                                      : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _locationMode = LocationSearchMode.specificLocation;
                      });
                      _validateSearchForm();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            _locationMode == LocationSearchMode.specificLocation
                                ? const Color(0xFFFFB300)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.place_rounded,
                            size: 16,
                            color: _locationMode ==
                                    LocationSearchMode.specificLocation
                                ? const Color(0xFF0F172A)
                                : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Specific Location",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: _locationMode ==
                                      LocationSearchMode.specificLocation
                                  ? const Color(0xFF0F172A)
                                  : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_locationMode == LocationSearchMode.specificLocation)
            Row(
              children: [
                Expanded(
                  child: _customSearchField(
                    "Area name, landmark, or hub",
                    _locationController,
                    Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _openMapPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFFB300).withOpacity(0.5),
                        ),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.map_rounded,
                            color: Color(0xFFFFB300),
                            size: 20,
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Map",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFB300),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (_locationMode == LocationSearchMode.specificLocation &&
              _pickedLatitude != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Pinned on map: ${_pickedLatitude!.toStringAsFixed(4)}, ${_pickedLongitude!.toStringAsFixed(4)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF86EFAC),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _customSearchField(
            "Minimum Experience (Years)",
            _experienceController,
            Icons.history_toggle_off_rounded,
            isNumber: true,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.radar_rounded,
                      color: Color(0xFFFFB300),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Search Radius",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 140,
                  child: _buildCustomDropdown(
                    value: _selectedRadius,
                    items: _radiusOptions,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRadius = val);
                      }
                    },
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
                backgroundColor: _isSearchButtonEnabled
                    ? const Color(0xFFFFB300)
                    : Colors.grey.shade400,
                foregroundColor: _isSearchButtonEnabled
                    ? const Color(0xFF0F172A)
                    : Colors.white24,
                disabledBackgroundColor: Colors.grey.shade400,
                disabledForegroundColor: Colors.white60,
                elevation: _isSearchButtonEnabled ? 4 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isSearchButtonEnabled && !_isFetchingGps
                  ? _navigateToResults
                  : null,
              child: _isFetchingGps
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF0F172A),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSearchButtonEnabled
                              ? Icons.search_rounded
                              : Icons.search_off_rounded,
                          size: 20,
                          color: _isSearchButtonEnabled
                              ? const Color(0xFF0F172A)
                              : Colors.white60,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Search Teachers",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _isSearchButtonEnabled
                                ? const Color(0xFF0F172A)
                                : Colors.white60,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF1E4C7A),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        icon: const Icon(
          Icons.arrow_drop_down_rounded,
          color: Color(0xFFFFB300),
          size: 24,
        ),
        items: items.map((String val) {
          return DropdownMenuItem<String>(
            value: val,
            child: Text(val, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: onChanged,
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
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB300), size: 18),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
      ),
    );
  }
}
