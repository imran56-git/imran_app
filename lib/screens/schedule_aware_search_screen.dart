import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/smart_match_result_model.dart';
import '../services/location_service.dart';
import '../services/smart_match_service.dart';
import '../widgets/teacher_card_widget.dart';
import 'chat_screen.dart';
import 'teacher_profile_screen.dart';

class ScheduleAwareSearchScreen extends StatefulWidget {
  const ScheduleAwareSearchScreen({super.key});

  @override
  State<ScheduleAwareSearchScreen> createState() =>
      _ScheduleAwareSearchScreenState();
}

class _ScheduleAwareSearchScreenState extends State<ScheduleAwareSearchScreen> {
  // Theme Color Palette
  static const Color _navy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _accentAmber = Color(0xFFF59E0B);
  static const Color _emerald = Color(0xFF059669);
  static const Color _slateBg = Color(0xFFF8FAFC);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _mutedSlate = Color(0xFF64748B);

  // Services
  final SmartMatchService _smartMatchService = SmartMatchService();
  final LocationService _locationService = LocationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Filter State
  final Set<String> _selectedDays = {'Monday', 'Wednesday', 'Friday'};
  String _selectedSlotType = 'evening'; // 'morning', 'afternoon', 'evening', 'custom'
  TimeOfDay _customStartTime = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay _customEndTime = const TimeOfDay(hour: 19, minute: 0);

  String? _selectedSubject = 'Mathematics';
  String? _selectedClass = 'Class 10';
  double _selectedRadiusKm = 10.0;
  bool _requireAvailableSeatsOnly = true;
  String _locationMode = 'gps'; // 'gps' or 'saved'

  // Location Coordinates
  double _currentLat = 22.5726;
  double _currentLng = 88.3639;
  bool _isLocating = false;

  // Search Execution & Results
  bool _hasSearched = false;
  bool _isSearching = false;
  bool _isFiltersCollapsed = false;
  List<SmartMatchResultModel> _searchResults = [];

  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<String> _subjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'Computer Science',
    'Economics',
    'Accountancy',
    'Bengali',
    'Hindi',
    'Social Science',
  ];

  final List<String> _classes = [
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10',
    'Class 11',
    'Class 12',
    'College / UG',
  ];

  final List<double> _radiusOptions = [1.0, 3.0, 5.0, 10.0, 20.0];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLocating = true);
    try {
      final loc = await _locationService.getCurrentLocation();
      if (loc != null && mounted) {
        setState(() {
          _currentLat = loc.latitude;
          _currentLng = loc.longitude;
        });
      }
    } catch (_) {
      // Keep defaults gracefully
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  void _getEffectiveTimeRange(
      void Function(String start, String end) onRange) {
    switch (_selectedSlotType) {
      case 'morning':
        onRange('06:00 AM', '12:00 PM');
        break;
      case 'afternoon':
        onRange('12:00 PM', '05:00 PM');
        break;
      case 'evening':
        onRange('05:00 PM', '10:00 PM');
        break;
      case 'custom':
        onRange(
          _formatTimeOfDay(_customStartTime),
          _formatTimeOfDay(_customEndTime),
        );
        break;
    }
  }

  Future<void> _executeScheduleSearch() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one preferred study day.'),
          backgroundColor: _accentAmber,
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _isFiltersCollapsed = true;
    });

    String startStr = '05:00 PM';
    String endStr = '10:00 PM';
    _getEffectiveTimeRange((start, end) {
      startStr = start;
      endStr = end;
    });

    try {
      final results = await _smartMatchService.findScheduleMatches(
        selectedDays: _selectedDays.toList(),
        startTime: startStr,
        endTime: endStr,
        subject: _selectedSubject,
        classLevel: _selectedClass,
        studentLatitude: _currentLat,
        studentLongitude: _currentLng,
        maxRadiusKm: _selectedRadiusKm,
        requireAvailableSeatsOnly: _requireAvailableSeatsOnly,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _slateBg,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterContainer(),
            const SizedBox(height: 16),
            if (!_isFiltersCollapsed) ...[
              _buildSearchTriggerButton(),
              const SizedBox(height: 20),
            ],
            if (_hasSearched) ...[
              if (_isFiltersCollapsed) ...[
                _buildExpandFiltersPrompt(),
                const SizedBox(height: 16),
              ],
              _buildResultsSection(),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _navy,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Schedule-Aware Search',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Find tutors matching your exact time & days',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      centerTitle: true,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_navy, Color(0xFF1E3A8A), _brandBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterContainer() {
    if (_isFiltersCollapsed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedDays.length} Days • ${_selectedSlotType.toUpperCase()} • $_selectedSubject',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _navy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Radius: ${_selectedRadiusKm.toInt()} KM • ${_selectedClass ?? 'All Classes'}',
                    style: const TextStyle(fontSize: 11.5, color: _mutedSlate),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _isFiltersCollapsed = false),
              icon: const Icon(Icons.tune, size: 16, color: _brandBlue),
              label: const Text(
                'Edit',
                style: TextStyle(
                    color: _brandBlue,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            offset: Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDaySelectionSection(),
          const Divider(height: 28, color: _cardBorder),
          _buildTimeSlotSection(),
          const Divider(height: 28, color: _cardBorder),
          _buildAcademicPreferencesSection(),
          const Divider(height: 28, color: _cardBorder),
          _buildDistanceAndSeatAvailabilitySection(),
        ],
      ),
    );
  }

  Widget _buildDaySelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: _brandBlue),
                SizedBox(width: 8),
                Text(
                  '1. Study Days',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _buildQuickActionText('Weekdays', () {
                  setState(() {
                    _selectedDays.clear();
                    _selectedDays.addAll([
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                    ]);
                  });
                }),
                const Text(' • ', style: TextStyle(color: _mutedSlate)),
                _buildQuickActionText('Weekends', () {
                  setState(() {
                    _selectedDays.clear();
                    _selectedDays.addAll(['Saturday', 'Sunday']);
                  });
                }),
                const Text(' • ', style: TextStyle(color: _mutedSlate)),
                _buildQuickActionText('Clear', () {
                  setState(() => _selectedDays.clear());
                }),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: _daysOfWeek.map((day) {
            final isSelected = _selectedDays.contains(day);
            final short = day.substring(0, 3);
            return FilterChip(
              label: Text(short),
              selected: isSelected,
              selectedColor: _brandBlue,
              backgroundColor: _slateBg,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : _navy,
              ),
              side: BorderSide(
                color: isSelected ? _brandBlue : _cardBorder,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedDays.add(day);
                  } else {
                    _selectedDays.remove(day);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickActionText(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _accentBlue,
        ),
      ),
    );
  }

  Widget _buildTimeSlotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.schedule_rounded, size: 16, color: _brandBlue),
            SizedBox(width: 8),
            Text(
              '2. Preferred Time Slot',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSlotCard(
                type: 'morning',
                icon: Icons.wb_sunny_outlined,
                title: 'Morning',
                timeRange: '6 AM – 12 PM',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSlotCard(
                type: 'afternoon',
                icon: Icons.light_mode_outlined,
                title: 'Afternoon',
                timeRange: '12 PM – 5 PM',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSlotCard(
                type: 'evening',
                icon: Icons.dark_mode_outlined,
                title: 'Evening',
                timeRange: '5 PM – 10 PM',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Custom Range Selector
        InkWell(
          onTap: () => setState(() => _selectedSlotType = 'custom'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _selectedSlotType == 'custom'
                  ? _brandBlue.withValues(alpha: 0.08)
                  : _slateBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedSlotType == 'custom'
                    ? _brandBlue
                    : _cardBorder,
                width: _selectedSlotType == 'custom' ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tune,
                      size: 16,
                      color: _selectedSlotType == 'custom'
                          ? _brandBlue
                          : _mutedSlate,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Custom Exact Range',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _selectedSlotType == 'custom'
                            ? _brandBlue
                            : _navy,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildTimePickerPill(
                      label: _formatTimeOfDay(_customStartTime),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _customStartTime,
                        );
                        if (picked != null) {
                          setState(() {
                            _customStartTime = picked;
                            _selectedSlotType = 'custom';
                          });
                        }
                      },
                    ),
                    const Text(' - ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: _mutedSlate)),
                    _buildTimePickerPill(
                      label: _formatTimeOfDay(_customEndTime),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _customEndTime,
                        );
                        if (picked != null) {
                          setState(() {
                            _customEndTime = picked;
                            _selectedSlotType = 'custom';
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotCard({
    required String type,
    required IconData icon,
    required String title,
    required String timeRange,
  }) {
    final isSelected = _selectedSlotType == type;
    return InkWell(
      onTap: () => setState(() => _selectedSlotType = type),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? _brandBlue : _slateBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _brandBlue : _cardBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _brandBlue.withValues(alpha: 0.25),
                    offset: const Offset(0, 3),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : _brandBlue,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : _navy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeRange,
              style: TextStyle(
                fontSize: 9.5,
                color: isSelected ? Colors.white70 : _mutedSlate,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerPill({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _cardBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: _navy,
          ),
        ),
      ),
    );
  }

  Widget _buildAcademicPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.school_outlined, size: 16, color: _brandBlue),
            SizedBox(width: 8),
            Text(
              '3. Academic Subject & Level',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                value: _selectedSubject,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: _slateBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                ),
                items: _subjects
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedSubject = val),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _selectedClass,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Class',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: _slateBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _cardBorder),
                  ),
                ),
                items: _classes
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedClass = val),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDistanceAndSeatAvailabilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.near_me_outlined, size: 16, color: _brandBlue),
                SizedBox(width: 8),
                Text(
                  '4. Location & Capacity Limit',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _buildLocationModeToggle('gps', 'Current GPS'),
                const SizedBox(width: 6),
                _buildLocationModeToggle('saved', 'Saved Home'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Maximum Radius (KM)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _mutedSlate),
        ),
        const SizedBox(height: 6),
        Row(
          children: _radiusOptions.map((r) {
            final isSel = _selectedRadiusKm == r;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () => setState(() => _selectedRadiusKm = r),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSel ? _brandBlue : _slateBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSel ? _brandBlue : _cardBorder,
                      ),
                    ),
                    child: Text(
                      '${r.toInt()} KM',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        color: isSel ? Colors.white : _navy,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _requireAvailableSeatsOnly
                ? const Color(0xFFECFDF5)
                : _slateBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _requireAvailableSeatsOnly
                  ? const Color(0xFFA7F3D0)
                  : _cardBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Only show batches with open seats',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _requireAvailableSeatsOnly ? _emerald : _navy,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Exclude fully-booked batches from results',
                      style: TextStyle(
                        fontSize: 11,
                        color: _requireAvailableSeatsOnly
                            ? const Color(0xFF047857)
                            : _mutedSlate,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _requireAvailableSeatsOnly,
                activeColor: _emerald,
                onChanged: (val) {
                  setState(() => _requireAvailableSeatsOnly = val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationModeToggle(String mode, String label) {
    final isSelected = _locationMode == mode;
    return InkWell(
      onTap: () => setState(() => _locationMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? _brandBlue.withValues(alpha: 0.1) : _slateBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? _brandBlue : _cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? _brandBlue : _mutedSlate,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTriggerButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [_navy, _brandBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F172A),
            offset: Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isSearching ? null : _executeScheduleSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isSearching
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.flash_on_rounded, color: _accentAmber, size: 20),
        label: Text(
          _isSearching ? 'Matching Schedules...' : 'Find Matching Batches',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandFiltersPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _brandBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_searchResults.length} Match${_searchResults.length == 1 ? '' : 'es'} Found',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _brandBlue,
                ),
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () => setState(() => _isFiltersCollapsed = false),
          icon: const Icon(Icons.filter_list, size: 16, color: _brandBlue),
          label: const Text(
            'Adjust Search Filters',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _brandBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    if (_isSearching) {
      return Column(
        children: List.generate(3, (index) => _buildShimmerResultCard()),
      );
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyStateView();
    }

    final currentUserId = _auth.currentUser?.uid ?? '';

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildSmartResultCard(result, currentUserId);
      },
    );
  }

  Widget _buildSmartResultCard(
      SmartMatchResultModel result, String currentUserId) {
    final int score = result.matchScore.round();
    final bool hasSeats = result.hasOpenSeats;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Match Indicator Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_navy, _brandBlue],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: Color(0xFFFBBF24), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '$score% Match',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasSeats
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hasSeats
                            ? '${result.remainingSeats ?? 1} Seats Available'
                            : 'Schedule Listed — Capacity Unknown',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: hasSeats ? _emerald : _accentAmber,
                        ),
                      ),
                    ),
                  ],
                ),
                if (result.calculatedDistanceKm != null)
                  Text(
                    '${result.calculatedDistanceKm!.toStringAsFixed(1)} KM away',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _mutedSlate,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _brandBlue.withValues(alpha: 0.1),
                      backgroundImage: (result.profileImageUrl != null &&
                              result.profileImageUrl!.isNotEmpty)
                          ? NetworkImage(result.profileImageUrl!)
                          : null,
                      child: (result.profileImageUrl == null ||
                              result.profileImageUrl!.isEmpty)
                          ? Text(
                              result.teacherName.isNotEmpty
                                  ? result.teacherName[0].toUpperCase()
                                  : 'T',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _brandBlue,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  result.teacherName,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: _navy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (result.isVerified ?? false) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified,
                                    size: 15, color: _emerald),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.locationText ?? 'Teaching Centre',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _mutedSlate,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Matching Batch Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _slateBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alarm_on, size: 16, color: _brandBlue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Matching Batch: ${result.batchName ?? 'Regular'} (${result.batchTime ?? 'Slot'}) • ${result.days?.join('/') ?? 'Scheduled'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _navy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TeacherProfileScreen(
                                currentUserId: result.teacherId,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _cardBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'View Profile',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _navy,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (currentUserId.isEmpty) return;
                          final chatRoomId =
                              '${result.teacherId}_$currentUserId';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatRoomId: chatRoomId,
                                receiverId: result.teacherId,
                                receiverName: result.teacherName,
                                receiverProfilePic:
                                    result.profileImageUrl ?? '',
                                currentUserId: currentUserId,
                                isTeacher: false,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 15),
                        label: const Text(
                          'Chat Now',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerResultCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _brandBlue,
        ),
      ),
    );
  }

  Widget _buildEmptyStateView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _brandBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.schedule_send_outlined,
                size: 40, color: _brandBlue),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Direct Schedule Overlaps',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No tutors have published batch hours matching your selected days and time frame. Try broadening your study days, expanding radius, or switching slot periods.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: _mutedSlate,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => setState(() => _isFiltersCollapsed = false),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text(
              'Broaden My Filters',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}