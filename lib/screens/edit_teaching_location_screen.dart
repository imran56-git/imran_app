import 'package:flutter/material.dart';
import '../models/teacher_location_model.dart';
import '../services/teacher_location_service.dart';
import 'location_picker_screen.dart';

class EditTeachingLocationScreen extends StatefulWidget {
  final TeacherLocationModel location;

  const EditTeachingLocationScreen({
    super.key,
    required this.location,
  });

  @override
  State<EditTeachingLocationScreen> createState() => _EditTeachingLocationScreenState();
}

class _EditTeachingLocationScreenState extends State<EditTeachingLocationScreen> {
  // Theme Color Palette
  static const Color _navy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _accentAmber = Color(0xFFF59E0B);
  static const Color _backgroundSlate = Color(0xFFF8FAFC);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _mutedSlate = Color(0xFF64748B);

  final _formKey = GlobalKey<FormState>();
  final TeacherLocationService _locationService = TeacherLocationService();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;
  final TextEditingController _customSubjectController = TextEditingController();

  late String _locationType;
  late String _teachingMode;
  late double _latitude;
  late double _longitude;
  late String _address;
  late Set<String> _selectedSubjects;
  late Set<String> _selectedClasses;
  late double _serviceRadiusKm;
  late bool _isActive;

  bool _isLocationChanged = false;
  bool _isSaving = false;

  final List<Map<String, String>> _locationTypes = [
    {'key': 'tuition_centre', 'label': 'Tuition Centre'},
    {'key': 'institute', 'label': 'Institute'},
    {'key': 'home_tuition', 'label': 'Home Tuition'},
    {'key': 'school', 'label': 'School'},
    {'key': 'other', 'label': 'Other'},
  ];

  final List<Map<String, String>> _teachingModes = [
    {'key': 'offline', 'label': 'Offline In-Person'},
    {'key': 'hybrid', 'label': 'Hybrid'},
    {'key': 'online', 'label': 'Online Base'},
  ];

  final List<String> _standardSubjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'Computer Science',
    'Economics',
    'Accountancy',
    'Social Science',
    'History',
    'Geography',
  ];

  final List<String> _standardClasses = [
    'Class 6-8',
    'Class 9',
    'Class 10',
    'Class 11',
    'Class 12',
    'College / UG',
    'Competitive Exam',
  ];

  @override
  void initState() {
    super.initState();
    _initFromLocation();
  }

  void _initFromLocation() {
    final loc = widget.location;
    _nameController = TextEditingController(text: loc.locationName);
    _address = loc.address;
    _addressController = TextEditingController(text: loc.address);
    _notesController = TextEditingController(text: loc.additionalNotes ?? '');

    _locationType = loc.locationType;
    _teachingMode = loc.teachingMode ?? 'offline';
    _latitude = loc.latitude;
    _longitude = loc.longitude;
    _selectedSubjects = Set<String>.from(loc.subjects ?? []);
    _selectedClasses = Set<String>.from(loc.classes ?? []);
    _serviceRadiusKm = (loc.radiusKm ?? 5.0).clamp(1.0, 20.0);
    _isActive = loc.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _customSubjectController.dispose();
    super.dispose();
  }

  bool _hasUnsavedChanges() {
    final loc = widget.location;
    if (_nameController.text.trim() != loc.locationName) return true;
    if (_address != loc.address) return true;
    if ((_notesController.text.trim()) != (loc.additionalNotes ?? '')) return true;
    if (_locationType != loc.locationType) return true;
    if (_teachingMode != (loc.teachingMode ?? 'offline')) return true;
    if (_latitude != loc.latitude || _longitude != loc.longitude) return true;
    if (_isActive != (loc.isActive ?? true)) return true;
    if (_locationType == 'home_tuition' && _serviceRadiusKm != (loc.radiusKm ?? 5.0)) return true;

    final initialSubjects = Set<String>.from(loc.subjects ?? []);
    if (_selectedSubjects.length != initialSubjects.length ||
        !_selectedSubjects.containsAll(initialSubjects)) {
      return true;
    }

    final initialClasses = Set<String>.from(loc.classes ?? []);
    if (_selectedClasses.length != initialClasses.length ||
        !_selectedClasses.containsAll(initialClasses)) {
      return true;
    }

    return false;
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges()) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Discard Changes?',
          style: TextStyle(color: _navy, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to exit without saving?',
          style: TextStyle(color: _mutedSlate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing', style: TextStyle(color: _brandBlue)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return discard ?? false;
  }

  Future<void> _changeMapPosition() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialAddress: _address,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (result is Map) {
          if (result['latitude'] != null) _latitude = (result['latitude'] as num).toDouble();
          if (result['longitude'] != null) _longitude = (result['longitude'] as num).toDouble();
          if (result['address'] != null && (result['address'] as String).isNotEmpty) {
            _address = result['address'];
            _addressController.text = _address;
          }
        }
        _isLocationChanged = true;
      });
    }
  }

  void _addCustomSubject() {
    final text = _customSubjectController.text.trim();
    if (text.isNotEmpty && !_selectedSubjects.contains(text)) {
      setState(() {
        _selectedSubjects.add(text);
        _customSubjectController.clear();
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the errors in the form.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one subject taught at this centre.'),
          backgroundColor: _accentAmber,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedLocation = widget.location.copyWith(
        locationName: _nameController.text.trim(),
        locationType: _locationType,
        address: _address.trim(),
        latitude: _latitude,
        longitude: _longitude,
        teachingMode: _teachingMode,
        subjects: _selectedSubjects.toList(),
        classes: _selectedClasses.toList(),
        radiusKm: _locationType == 'home_tuition' ? _serviceRadiusKm : null,
        additionalNotes: _notesController.text.trim(),
        isActive: _isActive,
        updatedAt: DateTime.now(),
      );

      await _locationService.updateTeachingLocation(updatedLocation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Teaching centre updated successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update location: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: _backgroundSlate,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: _navy, size: 20),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text(
            'Edit Teaching Centre',
            style: TextStyle(
              color: _navy,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _isSaving
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _brandBlue,
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: _handleSave,
                      style: TextButton.styleFrom(
                        backgroundColor: _brandBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(height: 1, color: _cardBorder),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBasicInfoSection(),
                const SizedBox(height: 16),
                _buildTypeAndModeSection(),
                const SizedBox(height: 16),
                _buildCoordinatesAndAddressSection(),
                const SizedBox(height: 16),
                if (_locationType == 'home_tuition') ...[
                  _buildServiceRadiusSection(),
                  const SizedBox(height: 16),
                ],
                _buildAcademicSection(),
                const SizedBox(height: 16),
                _buildNotesSection(),
                const SizedBox(height: 24),
                _buildActionFooter(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _brandBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: _brandBlue),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _navy,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12.5, color: _mutedSlate),
          ),
        ],
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildCardContainer(
      children: [
        _buildSectionHeader(
          icon: Icons.storefront_outlined,
          title: 'Centre Overview',
          subtitle: 'Define display identity and real-time operational status',
        ),
        TextFormField(
          controller: _nameController,
          style: const TextStyle(fontSize: 14.5, color: _navy, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: 'Centre or Location Name *',
            hintText: 'e.g., Apex Academy - Central Branch',
            filled: true,
            fillColor: _backgroundSlate,
            prefixIcon: const Icon(Icons.business, color: _brandBlue, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _accentBlue, width: 1.5),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Centre name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isActive ? const Color(0xFFA7F3D0) : _cardBorder,
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
                      _isActive ? 'Centre Active & Visible' : 'Centre Deactivated',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isActive ? const Color(0xFF065F46) : _navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isActive
                          ? 'Students can locate and book sessions at this centre'
                          : 'Temporarily hide this centre from public searches',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _isActive ? const Color(0xFF047857) : _mutedSlate,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _isActive,
                activeColor: const Color(0xFF10B981),
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeAndModeSection() {
    return _buildCardContainer(
      children: [
        _buildSectionHeader(
          icon: Icons.category_outlined,
          title: 'Classification & Delivery',
          subtitle: 'Categorize your premises and how lectures are conducted',
        ),
        const Text(
          'Premises Type',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _navy),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _locationTypes.map((type) {
            final isSelected = _locationType == type['key'];
            return ChoiceChip(
              label: Text(type['label']!),
              selected: isSelected,
              selectedColor: _brandBlue,
              backgroundColor: _backgroundSlate,
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : _navy,
              ),
              side: BorderSide(
                color: isSelected ? _brandBlue : _cardBorder,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (selected) {
                if (selected) setState(() => _locationType = type['key']!);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        const Text(
          'Teaching Delivery Mode',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _navy),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _teachingModes.map((mode) {
            final isSelected = _teachingMode == mode['key'];
            return ChoiceChip(
              label: Text(mode['label']!),
              selected: isSelected,
              selectedColor: _accentBlue,
              backgroundColor: _backgroundSlate,
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : _navy,
              ),
              side: BorderSide(
                color: isSelected ? _accentBlue : _cardBorder,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (selected) {
                if (selected) setState(() => _teachingMode = mode['key']!);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCoordinatesAndAddressSection() {
    return _buildCardContainer(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSectionHeader(
                icon: Icons.map_outlined,
                title: 'Geographic Location',
                subtitle: 'Physical GPS position for accurate map pin routing',
              ),
            ),
            if (_isLocationChanged)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _accentAmber.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 12, color: _accentAmber),
                    SizedBox(width: 4),
                    Text(
                      'Pin Updated',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _backgroundSlate,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: _brandBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _address.isNotEmpty ? _address : 'No address set',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: _cardBorder),
              Row(
                children: [
                  Expanded(
                    child: _buildCoordinatePill(
                      label: 'LATITUDE',
                      value: _latitude.toStringAsFixed(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCoordinatePill(
                      label: 'LONGITUDE',
                      value: _longitude.toStringAsFixed(6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _changeMapPosition,
            icon: const Icon(Icons.pin_drop, size: 18),
            label: const Text('Change Map Position'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brandBlue,
              side: const BorderSide(color: _brandBlue, width: 1.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoordinatePill({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: _mutedSlate,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _navy,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceRadiusSection() {
    return _buildCardContainer(
      children: [
        _buildSectionHeader(
          icon: Icons.radar,
          title: 'Home Tuition Coverage Radius',
          subtitle: 'Maximum driving distance for at-home visits',
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Max Travel Distance',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _navy),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _brandBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_serviceRadiusKm.toStringAsFixed(1)} KM',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _brandBlue,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _brandBlue,
            inactiveTrackColor: _cardBorder,
            thumbColor: _brandBlue,
            overlayColor: _brandBlue.withValues(alpha: 0.1),
            valueIndicatorColor: _navy,
          ),
          child: Slider(
            value: _serviceRadiusKm,
            min: 1.0,
            max: 20.0,
            divisions: 38,
            label: '${_serviceRadiusKm.toStringAsFixed(1)} km',
            onChanged: (val) {
              setState(() => _serviceRadiusKm = val);
            },
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1.0 KM', style: TextStyle(fontSize: 11, color: _mutedSlate)),
            Text('10.0 KM', style: TextStyle(fontSize: 11, color: _mutedSlate)),
            Text('20.0 KM', style: TextStyle(fontSize: 11, color: _mutedSlate)),
          ],
        ),
      ],
    );
  }

  Widget _buildAcademicSection() {
    return _buildCardContainer(
      children: [
        _buildSectionHeader(
          icon: Icons.school_outlined,
          title: 'Academic Coverage',
          subtitle: 'Selected subjects and grade levels handled at this venue',
        ),
        const Text(
          'Subjects Taught',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _navy),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _standardSubjects.map((subject) {
            final isSelected = _selectedSubjects.contains(subject);
            return FilterChip(
              label: Text(subject),
              selected: isSelected,
              selectedColor: _accentBlue.withValues(alpha: 0.15),
              checkmarkColor: _accentBlue,
              backgroundColor: _backgroundSlate,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? _accentBlue : _navy,
              ),
              side: BorderSide(
                color: isSelected ? _accentBlue : _cardBorder,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSubjects.add(subject);
                  } else {
                    _selectedSubjects.remove(subject);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _customSubjectController,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Add custom subject...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: _backgroundSlate,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _cardBorder),
                    ),
                  ),
                  onSubmitted: (_) => _addCustomSubject(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: _addCustomSubject,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Add', style: TextStyle(fontSize: 12.5)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Classes / Standards',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _navy),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _standardClasses.map((cls) {
            final isSelected = _selectedClasses.contains(cls);
            return FilterChip(
              label: Text(cls),
              selected: isSelected,
              selectedColor: _brandBlue.withValues(alpha: 0.15),
              checkmarkColor: _brandBlue,
              backgroundColor: _backgroundSlate,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? _brandBlue : _navy,
              ),
              side: BorderSide(
                color: isSelected ? _brandBlue : _cardBorder,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedClasses.add(cls);
                  } else {
                    _selectedClasses.remove(cls);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return _buildCardContainer(
      children: [
        _buildSectionHeader(
          icon: Icons.description_outlined,
          title: 'Additional Directives & Notes',
          subtitle: 'Landmark directions, parking instructions, entry protocols',
        ),
        TextFormField(
          controller: _notesController,
          maxLines: 4,
          style: const TextStyle(fontSize: 13.5, color: _navy),
          decoration: InputDecoration(
            hintText: 'e.g., 2nd floor, elevator available, park behind the building...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            filled: true,
            fillColor: _backgroundSlate,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _accentBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionFooter() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: _cardBorder, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _mutedSlate, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_outlined, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Save Updates',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}