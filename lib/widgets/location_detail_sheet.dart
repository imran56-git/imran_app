import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/teacher_location_model.dart';
import '../models/teaching_batch_model.dart';
import '../models/teaching_schedule_model.dart';
import '../screens/chat_screen.dart';
import '../screens/location_batch_schedule_screen.dart';
import '../screens/teacher_profile_screen.dart';
import '../services/google_maps_route_service.dart';
import '../services/teacher_location_service.dart';

class LocationDetailSheet extends StatefulWidget {
  final TeacherLocationModel location;
  final String teacherName;
  final String? teacherPhotoUrl;
  final double? studentLat;
  final double? studentLng;

  const LocationDetailSheet({
    super.key,
    required this.location,
    required this.teacherName,
    this.teacherPhotoUrl,
    this.studentLat,
    this.studentLng,
  });

  static Future<void> show(
    BuildContext context, {
    required TeacherLocationModel location,
    required String teacherName,
    String? teacherPhotoUrl,
    double? studentLat,
    double? studentLng,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationDetailSheet(
        location: location,
        teacherName: teacherName,
        teacherPhotoUrl: teacherPhotoUrl,
        studentLat: studentLat,
        studentLng: studentLng,
      ),
    );
  }

  @override
  State<LocationDetailSheet> createState() => _LocationDetailSheetState();
}

class _LocationDetailSheetState extends State<LocationDetailSheet> {
  // Theme Color Palette
  static const Color _navy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _emerald = Color(0xFF059669);
  static const Color _accentAmber = Color(0xFFF59E0B);
  static const Color _slateBg = Color(0xFFF8FAFC);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _mutedSlate = Color(0xFF64748B);

  final TeacherLocationService _locationService = TeacherLocationService();
  final GoogleMapsRouteService _routeService = GoogleMapsRouteService();

  int _selectedSegmentIndex = 0; // 0: Batches, 1: Timetable, 2: About & Rules
  String _travelMode = 'driving'; // 'driving' or 'walking'
  bool _isCalculatingCommute = false;
  double? _commuteDistanceKm;
  int? _commuteDurationMinutes;

  @override
  void initState() {
    super.initState();
    _calculateCommute();
  }

  Future<void> _calculateCommute() async {
    if (widget.studentLat == null || widget.studentLng == null) return;

    setState(() => _isCalculatingCommute = true);

    try {
      final route = await _routeService.getRouteDetails(
        originLat: widget.studentLat!,
        originLng: widget.studentLng!,
        destLat: widget.location.latitude,
        destLng: widget.location.longitude,
      );

      if (mounted && route != null) {
        setState(() {
          _commuteDistanceKm = route.distanceKm;
          _commuteDurationMinutes = _travelMode == 'driving'
              ? route.durationMinutes
              : (route.distanceKm / 4.8 * 60).round();
          _isCalculatingCommute = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback: Haversine distance
    if (mounted) {
      final directKm = _haversine(
        widget.studentLat!,
        widget.studentLng!,
        widget.location.latitude,
        widget.location.longitude,
      );
      final roadKm = directKm * 1.28;
      final speedKmh = _travelMode == 'driving' ? 24.0 : 4.8;
      final minutes = (roadKm / speedKmh * 60).round().clamp(2, 300);

      setState(() {
        _commuteDistanceKm = roadKm;
        _commuteDurationMinutes = minutes;
        _isCalculatingCommute = false;
      });
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  void _copyAddressToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.location.address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address copied to clipboard!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _launchDirections() async {
    final lat = widget.location.latitude;
    final lng = widget.location.longitude;
    final Uri appUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    final Uri webUrl =
        Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");

    try {
      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Cannot launch map directions';
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open map application.')),
        );
      }
    }
  }

  String _formatLocationType(String type) {
    switch (type.toLowerCase()) {
      case 'tuition_centre':
        return 'Tuition Centre';
      case 'institute':
        return 'Institute / Academy';
      case 'home_tuition':
        return 'Home Tuition Base';
      case 'school':
        return 'School Campus';
      default:
        return 'Teaching Zone';
    }
  }

  IconData _getLocationTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'tuition_centre':
        return Icons.business_outlined;
      case 'institute':
        return Icons.account_balance_outlined;
      case 'home_tuition':
        return Icons.home_work_outlined;
      case 'school':
        return Icons.school_outlined;
      default:
        return Icons.location_on_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x280F172A),
                blurRadius: 28,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTopGrabHandle(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildHeaderSection(),
                    if (widget.studentLat != null && widget.studentLng != null) ...[
                      const SizedBox(height: 14),
                      _buildCommuteProximityBar(),
                    ],
                    const SizedBox(height: 18),
                    _buildSegmentController(),
                    const SizedBox(height: 16),
                    _buildSegmentBody(),
                    const SizedBox(height: 100), // Spacing for sticky bottom bar
                  ],
                ),
              ),
              _buildStickyBottomActionBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopGrabHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final loc = widget.location;
    final isVerified = loc.verificationStatus == 'verified';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _brandBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _brandBlue.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getLocationTypeIcon(loc.locationType),
                          size: 14, color: _brandBlue),
                      const SizedBox(width: 5),
                      Text(
                        _formatLocationType(loc.locationType),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _brandBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, size: 13, color: _emerald),
                        SizedBox(width: 4),
                        Text(
                          'Verified Centre',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 22, color: _mutedSlate),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          loc.locationName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: _navy,
            letterSpacing: -0.3,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        // Teacher Profile Info Tile
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherProfileScreen(currentUserId: loc.teacherId),
              ),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _brandBlue.withValues(alpha: 0.1),
                backgroundImage: (widget.teacherPhotoUrl != null &&
                        widget.teacherPhotoUrl!.isNotEmpty)
                    ? NetworkImage(widget.teacherPhotoUrl!)
                    : null,
                child: (widget.teacherPhotoUrl == null ||
                        widget.teacherPhotoUrl!.isEmpty)
                    ? Text(
                        widget.teacherName.isNotEmpty
                            ? widget.teacherName[0].toUpperCase()
                            : 'T',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _brandBlue,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      widget.teacherName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle_rounded,
                        size: 13, color: _accentBlue),
                  ],
                ),
              ),
              const Text(
                'View Profile',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _accentBlue,
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: _accentBlue),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Address Bar with Copy Action
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _slateBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.place_outlined, size: 16, color: Color(0xFFEF4444)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.address,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _navy,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _copyAddressToClipboard,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.copy_rounded, size: 16, color: _mutedSlate),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommuteProximityBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _travelMode == 'driving'
                    ? Icons.directions_car_rounded
                    : Icons.directions_walk_rounded,
                size: 18,
                color: _brandBlue,
              ),
              const SizedBox(width: 8),
              if (_isCalculatingCommute)
                const Text(
                  'Estimating route...',
                  style: TextStyle(fontSize: 12, color: _mutedSlate),
                )
              else if (_commuteDistanceKm != null && _commuteDurationMinutes != null)
                Text(
                  '${_commuteDistanceKm!.toStringAsFixed(1)} KM • $_commuteDurationMinutes mins',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                )
              else
                const Text(
                  'Proximity estimation unavailable',
                  style: TextStyle(fontSize: 12, color: _mutedSlate),
                ),
            ],
          ),
          // Toggle Driving vs Walking
          Row(
            children: [
              _buildCommuteModePill('driving', Icons.directions_car),
              const SizedBox(width: 4),
              _buildCommuteModePill('walking', Icons.directions_walk),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommuteModePill(String mode, IconData icon) {
    final isSelected = _travelMode == mode;
    return InkWell(
      onTap: () {
        if (_travelMode != mode) {
          setState(() => _travelMode = mode);
          _calculateCommute();
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _brandBlue : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? _brandBlue : _cardBorder),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isSelected ? Colors.white : _mutedSlate,
        ),
      ),
    );
  }

  Widget _buildSegmentController() {
    final segments = [
      'Active Batches',
      'Timetable',
      'Centre & Rules',
    ];

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: _slateBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: List.generate(segments.length, (index) {
          final isSelected = _selectedSegmentIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedSegmentIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Color(0x0A0F172A),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  segments[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? _navy : _mutedSlate,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSegmentBody() {
    switch (_selectedSegmentIndex) {
      case 0:
        return _buildBatchesSegment();
      case 1:
        return _buildTimetableSegment();
      case 2:
      default:
        return _buildAboutAndRulesSegment();
    }
  }

  // --- SEGMENT 1: ACTIVE BATCHES & CAPACITY ---
  Widget _buildBatchesSegment() {
    return StreamBuilder<List<TeachingBatchModel>>(
      stream: _locationService.getBatchesStream(
        widget.location.teacherId,
        widget.location.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: _brandBlue, strokeWidth: 2),
            ),
          );
        }

        final batches = snapshot.data ?? [];

        if (batches.isEmpty) {
          return _buildEmptySegmentView(
            icon: Icons.groups_outlined,
            title: 'No Active Classroom Batches',
            description:
                'Tutor has not configured scheduled batches for this location yet. Please contact educator directly via Chat.',
          );
        }

        return Column(
          children: batches.map((batch) {
            final max = batch.maxCapacity;
            final enrolled = batch.enrolledCount ?? 0;
            final remaining = (max - enrolled).clamp(0, max);
            final ratio = max > 0 ? (enrolled / max).clamp(0.0, 1.0) : 0.0;

            Color statusColor;
            String statusLabel;
            Color statusBg;

            if (remaining == 0) {
              statusColor = const Color(0xFFDC2626);
              statusBg = const Color(0xFFFEE2E2);
              statusLabel = 'Full';
            } else if (remaining <= 3 || ratio >= 0.8) {
              statusColor = _accentAmber;
              statusBg = const Color(0xFFFEF3C7);
              statusLabel = 'Few Seats Left';
            } else {
              statusColor = _emerald;
              statusBg = const Color(0xFFECFDF5);
              statusLabel = 'Available';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          batch.batchName,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: _brandBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          batch.subject,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _brandBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: _slateBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _cardBorder),
                        ),
                        child: Text(
                          batch.classLevel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Enrolled: $enrolled / $max Seats',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _navy),
                      ),
                      Text(
                        '$remaining seat${remaining == 1 ? '' : 's'} open',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: statusColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 5,
                      backgroundColor: _slateBg,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 13, color: _mutedSlate),
                      const SizedBox(width: 4),
                      Text(
                        '${batch.startTime} – ${batch.endTime}',
                        style: const TextStyle(fontSize: 11.5, color: _navy),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.calendar_month, size: 13, color: _mutedSlate),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          batch.days.join(', '),
                          style: const TextStyle(fontSize: 11.5, color: _mutedSlate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // --- SEGMENT 2: WEEKLY TIMETABLE ---
  Widget _buildTimetableSegment() {
    return StreamBuilder<List<TeachingScheduleModel>>(
      stream: _locationService.getSchedulesStream(
        widget.location.teacherId,
        widget.location.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: _brandBlue, strokeWidth: 2),
            ),
          );
        }

        final schedules = snapshot.data ?? [];

        if (schedules.isEmpty) {
          return _buildEmptySegmentView(
            icon: Icons.calendar_month_outlined,
            title: 'No Timetable Slots Published',
            description:
                'Scheduled time slots for this venue are not yet indexed on the calendar.',
          );
        }

        final days = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];

        return Column(
          children: [
            ...days.map((day) {
              final daySlots = schedules
                  .where((s) => s.dayOfWeek.toLowerCase() == day.toLowerCase())
                  .toList();

              if (daySlots.isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...daySlots.map((slot) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _accentBlue,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${slot.startTime} – ${slot.endTime}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _navy,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${slot.subject} (${slot.batchName})',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: _mutedSlate,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LocationBatchScheduleScreen(location: widget.location),
                    ),
                  );
                },
                icon: const Icon(Icons.fullscreen_rounded, size: 18),
                label: const Text('Open Full Interactive Schedule Screen'),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- SEGMENT 3: ABOUT CENTRE & RULES ---
  Widget _buildAboutAndRulesSegment() {
    final loc = widget.location;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operational Mode',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _mutedSlate),
          ),
          const SizedBox(height: 4),
          Text(
            loc.teachingMode?.toUpperCase() ?? 'OFFLINE IN-PERSON',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: _navy),
          ),
          const SizedBox(height: 12),
          const Text(
            'Subjects Handled at this Centre',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _mutedSlate),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (loc.subjects ?? ['General Academic']).map((sub) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: _slateBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _cardBorder),
                ),
                child: Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            'Classes / Standards',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _mutedSlate),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (loc.classes ?? ['All Levels']).map((cls) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: _brandBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cls,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: _brandBlue,
                  ),
                ),
              );
            }).toList(),
          ),
          if (loc.additionalNotes != null && loc.additionalNotes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Landmark & Access Instructions',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _mutedSlate),
            ),
            const SizedBox(height: 4),
            Text(
              loc.additionalNotes!,
              style: const TextStyle(fontSize: 13, color: _navy, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptySegmentView({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: _slateBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: _mutedSlate),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: _navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: _mutedSlate),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomActionBar() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _cardBorder, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Action 1: Navigate
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: _launchDirections,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.navigation_rounded, size: 16),
              label: const Text(
                'Directions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Action 2: Chat
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: () {
                if (currentUserId.isEmpty) return;
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatRoomId: '${widget.location.teacherId}_$currentUserId',
                      receiverId: widget.location.teacherId,
                      receiverName: widget.teacherName,
                      receiverProfilePic: widget.teacherPhotoUrl ?? '',
                      currentUserId: currentUserId,
                      isTeacher: false,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text(
                'Chat',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Action 3: Profile
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherProfileScreen(
                      currentUserId: widget.location.teacherId,
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _cardBorder, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Profile',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _navy,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}