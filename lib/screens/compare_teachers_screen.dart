import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/teacher_location_model.dart';
import '../models/teaching_batch_model.dart';
import '../services/google_maps_route_service.dart';
import '../services/teacher_location_service.dart';
import 'chat_screen.dart';
import 'teacher_profile_screen.dart';

class CompareTeachersScreen extends StatefulWidget {
  final List<String> teacherIds;
  final double studentLat;
  final double studentLng;

  const CompareTeachersScreen({
    super.key,
    required this.teacherIds,
    required this.studentLat,
    required this.studentLng,
  });

  @override
  State<CompareTeachersScreen> createState() => _CompareTeachersScreenState();
}

class _CompareTeachersScreenState extends State<CompareTeachersScreen> {
  // Theme Color Palette
  static const Color _navy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _emerald = Color(0xFF059669);
  static const Color _accentAmber = Color(0xFFF59E0B);
  static const Color _slateBg = Color(0xFFF8FAFC);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _mutedSlate = Color(0xFF64748B);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TeacherLocationService _locationService = TeacherLocationService();
  final GoogleMapsRouteService _routeService = GoogleMapsRouteService();

  late List<String> _activeTeacherIds;
  bool _isLoading = true;
  String? _errorMessage;
  List<_TeacherComparisonProfile> _profiles = [];

  @override
  void initState() {
    super.initState();
    _activeTeacherIds = List<String>.from(widget.teacherIds.take(4));
    _loadAllComparisonData();
  }

  double _calculateHaversine(double lat1, double lon1, double lat2, double lon2) {
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

  Future<void> _loadAllComparisonData() async {
    if (_activeTeacherIds.length < 2) {
      setState(() {
        _isLoading = false;
        _profiles = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final futures = _activeTeacherIds.map((id) => _fetchSingleProfile(id));
      final loaded = await Future.wait(futures);

      if (mounted) {
        setState(() {
          _profiles = loaded.whereType<_TeacherComparisonProfile>().toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load comparison data: $e';
        });
      }
    }
  }

  Future<_TeacherComparisonProfile?> _fetchSingleProfile(String teacherId) async {
    try {
      final doc = await _firestore.collection('teachers').doc(teacherId).get();
      if (!doc.exists) return null;

      final data = doc.data() ?? {};
      final String name = (data['name'] ?? data['fullName'] ?? 'Educator').toString();
      final String profileUrl = (data['profileImageUrl'] ?? data['photoUrl'] ?? '').toString();
      final bool isVerified = data['isVerified'] == true || data['status'] == 'approved';

      final double rating = double.tryParse(
              (data['averageRating'] ?? data['rating'] ?? '0.0').toString()) ??
          0.0;
      final int reviewCount = int.tryParse(
              (data['reviewCount'] ?? data['reviews'] ?? '0').toString()) ??
          0;

      final rawExp = data['experience'] ?? data['teachingExperience'] ?? data['experienceYears'] ?? 0;
      int experienceYears = 0;
      if (rawExp is num) {
        experienceYears = rawExp.toInt();
      } else {
        final match = RegExp(r'\d+').firstMatch(rawExp.toString());
        if (match != null) experienceYears = int.tryParse(match.group(0)!) ?? 0;
      }

      List<String> subjects = [];
      if (data['subjects'] is List) {
        subjects = List<String>.from(data['subjects'].map((x) => x.toString()));
      }

      List<String> classes = [];
      if (data['classes'] is List) {
        classes = List<String>.from(data['classes'].map((x) => x.toString()));
      } else if (data['class'] != null) {
        classes = [data['class'].toString()];
      }

      // Fetch Sub-collection Locations
      List<TeacherLocationModel> locations = [];
      try {
        locations = await _locationService.getTeacherLocations(teacherId);
      } catch (_) {}

      // Fallback location if subcollection is empty
      if (locations.isEmpty && data['latitude'] != null && data['longitude'] != null) {
        final double? lat = double.tryParse(data['latitude'].toString());
        final double? lng = double.tryParse(data['longitude'].toString());
        if (lat != null && lng != null) {
          locations.add(
            TeacherLocationModel(
              id: 'primary',
              teacherId: teacherId,
              locationName: (data['institute'] ?? 'Main Centre').toString(),
              locationType: 'tuition_centre',
              address: (data['address'] ?? data['location'] ?? 'Location Available').toString(),
              latitude: lat,
              longitude: lng,
              teachingMode: (data['teachingMode'] ?? 'offline').toString(),
              createdAt: DateTime.now(),
            ),
          );
        }
      }

      // Fetch Batches
      List<TeachingBatchModel> batches = [];
      if (locations.isNotEmpty) {
        try {
          final bList = await _locationService.getBatches(teacherId, locations.first.id);
          batches.addAll(bList);
        } catch (_) {}
      }

      // Calculate Proximity based on nearest location
      double minStraightDistance = 9999.0;
      double chosenLat = 0.0;
      double chosenLng = 0.0;

      for (var loc in locations) {
        final dist = _calculateHaversine(widget.studentLat, widget.studentLng, loc.latitude, loc.longitude);
        if (dist < minStraightDistance) {
          minStraightDistance = dist;
          chosenLat = loc.latitude;
          chosenLng = loc.longitude;
        }
      }

      double roadDistanceKm = minStraightDistance * 1.28; // fallback realistic route ratio
      int estimatedMinutes = (roadDistanceKm / 24.0 * 60).round().clamp(3, 180);

      if (chosenLat != 0.0 && chosenLng != 0.0) {
        try {
          final routeInfo = await _routeService.getRouteDetails(
            originLat: widget.studentLat,
            originLng: widget.studentLng,
            destLat: chosenLat,
            destLng: chosenLng,
          );
          if (routeInfo != null) {
            roadDistanceKm = routeInfo.distanceKm;
            estimatedMinutes = routeInfo.durationMinutes;
          }
        } catch (_) {}
      }

      return _TeacherComparisonProfile(
        id: teacherId,
        name: name,
        profileImageUrl: profileUrl,
        isVerified: isVerified,
        rating: rating,
        reviewCount: reviewCount,
        experienceYears: experienceYears,
        subjects: subjects,
        classes: classes,
        locations: locations,
        batches: batches,
        straightLineDistanceKm: minStraightDistance < 9000 ? minStraightDistance : null,
        roadDistanceKm: roadDistanceKm < 9000 ? roadDistanceKm : null,
        estimatedTravelMinutes: estimatedMinutes,
      );
    } catch (_) {
      return null;
    }
  }

  void _removeTeacher(String id) {
    setState(() {
      _activeTeacherIds.remove(id);
      _profiles.removeWhere((p) => p.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _slateBg,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _navy,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Compare Educators',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Side-by-side academic & proximity analysis',
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _brandBlue, strokeWidth: 3),
            SizedBox(height: 16),
            Text(
              'Compiling Side-by-Side Analysis...',
              style: TextStyle(
                color: _navy,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_activeTeacherIds.length < 2 || _profiles.length < 2) {
      return _buildInsufficientTeachersView();
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 44, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _navy, fontSize: 13.5),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAllComparisonData,
                style: ElevatedButton.styleFrom(backgroundColor: _brandBlue),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    // Determine Metric Winners for Highlights
    final double minDistance = _profiles
        .map((p) => p.roadDistanceKm ?? 9999.0)
        .reduce(math.min);
    final double maxRating = _profiles.map((p) => p.rating).reduce(math.max);
    final int maxExperience = _profiles.map((p) => p.experienceYears).reduce(math.max);

    final double screenWidth = MediaQuery.of(context).size.width;
    final double columnWidth = (screenWidth * 0.72).clamp(260.0, 310.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'COMPARING ${_profiles.length} EDUCATORS',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _mutedSlate,
                    letterSpacing: 0.8,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _brandBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.swipe_left_rounded, size: 14, color: _brandBlue),
                      SizedBox(width: 4),
                      Text(
                        'Scroll Horizontally',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _brandBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _profiles.map((profile) {
                final bool isNearest = (profile.roadDistanceKm != null &&
                    profile.roadDistanceKm! <= minDistance &&
                    minDistance < 9000);
                final bool isTopRated = (profile.rating >= maxRating && maxRating > 0);
                final bool isMostExperienced =
                    (profile.experienceYears >= maxExperience && maxExperience > 0);

                return Container(
                  width: columnWidth,
                  margin: const EdgeInsets.only(right: 14),
                  child: Column(
                    children: [
                      _buildTeacherStickyHeaderCard(
                        profile,
                        isNearest: isNearest,
                        isTopRated: isTopRated,
                        isMostExperienced: isMostExperienced,
                      ),
                      const SizedBox(height: 12),
                      _buildProximitySection(profile, isNearest),
                      const SizedBox(height: 12),
                      _buildCentresAndModeSection(profile),
                      const SizedBox(height: 12),
                      _buildSubjectsAndClassesSection(profile),
                      const SizedBox(height: 12),
                      _buildBatchesAndScheduleSection(profile),
                      const SizedBox(height: 12),
                      _buildExperienceAndRatingsSection(profile, isTopRated, isMostExperienced),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherStickyHeaderCard(
    _TeacherComparisonProfile profile, {
    required bool isNearest,
    required bool isTopRated,
    required bool isMostExperienced,
  }) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTopRated
              ? _accentAmber
              : isNearest
                  ? _emerald
                  : _cardBorder,
          width: (isTopRated || isNearest) ? 1.8 : 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Winner Tag Chip
              if (isTopRated)
                _buildWinnerBadge('Top Rated', _accentAmber, Icons.star_rounded)
              else if (isNearest)
                _buildWinnerBadge('Nearest', _emerald, Icons.near_me_rounded)
              else if (isMostExperienced)
                _buildWinnerBadge('Most Exp.', _brandBlue, Icons.workspace_premium_rounded)
              else
                const SizedBox(height: 22),
              // Close / Remove Button
              InkWell(
                onTap: () => _removeTeacher(profile.id),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _slateBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: _cardBorder),
                  ),
                  child: const Icon(Icons.close_rounded, size: 14, color: _mutedSlate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CircleAvatar(
            radius: 30,
            backgroundColor: _brandBlue.withValues(alpha: 0.1),
            backgroundImage: profile.profileImageUrl.isNotEmpty
                ? NetworkImage(profile.profileImageUrl)
                : null,
            child: profile.profileImageUrl.isEmpty
                ? Text(
                    profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'T',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _brandBlue,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified, size: 15, color: _emerald),
              ],
            ],
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
                        builder: (_) => TeacherProfileScreen(currentUserId: profile.id),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Profile', style: TextStyle(color: _navy)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (currentUserId.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          chatRoomId: '${profile.id}_$currentUserId',
                          receiverId: profile.id,
                          receiverName: profile.name,
                          receiverProfilePic: profile.profileImageUrl,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Chat'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool isHighlighted = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? _emerald.withValues(alpha: 0.4) : _cardBorder,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: isHighlighted ? _emerald : _brandBlue),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isHighlighted ? _emerald : _mutedSlate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProximitySection(_TeacherComparisonProfile profile, bool isNearest) {
    final dist = profile.roadDistanceKm;
    final mins = profile.estimatedTravelMinutes;

    return _buildSectionCard(
      title: 'Proximity & Commute',
      icon: Icons.directions_car_filled_outlined,
      isHighlighted: isNearest,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dist != null ? '${dist.toStringAsFixed(1)} KM' : 'Distance N/A',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mins != null ? '~$mins mins road travel' : 'Estimated time N/A',
                  style: const TextStyle(fontSize: 11.5, color: _mutedSlate),
                ),
              ],
            ),
            if (isNearest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'CLOSEST',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _emerald),
                ),
              ),
          ],
        ),
        if (profile.straightLineDistanceKm != null) ...[
          const SizedBox(height: 8),
          Text(
            'Direct: ${profile.straightLineDistanceKm!.toStringAsFixed(1)} KM straight line',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ],
    );
  }

  Widget _buildCentresAndModeSection(_TeacherComparisonProfile profile) {
    final loc = profile.locations.isNotEmpty ? profile.locations.first : null;
    final mode = loc?.teachingMode ?? 'offline';

    return _buildSectionCard(
      title: 'Teaching Centre & Mode',
      icon: Icons.storefront_outlined,
      children: [
        Text(
          loc?.locationName ?? 'Independent Tutoring',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _navy),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          loc?.address ?? 'No physical centre configured',
          style: const TextStyle(fontSize: 11, color: _mutedSlate),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _slateBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _cardBorder),
          ),
          child: Text(
            mode.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _brandBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectsAndClassesSection(_TeacherComparisonProfile profile) {
    return _buildSectionCard(
      title: 'Subjects & Standards',
      icon: Icons.school_outlined,
      children: [
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: profile.subjects.take(4).map((sub) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _brandBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                sub,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _brandBlue),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: profile.classes.take(3).map((cls) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _slateBg,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: _cardBorder),
              ),
              child: Text(
                cls,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _navy),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBatchesAndScheduleSection(_TeacherComparisonProfile profile) {
    final batchCount = profile.batches.length;
    int openSeats = 0;
    for (var b in profile.batches) {
      final enrolled = b.enrolledCount ?? 0;
      openSeats += (b.maxCapacity - enrolled).clamp(0, b.maxCapacity);
    }

    return _buildSectionCard(
      title: 'Batches & Timetable',
      icon: Icons.calendar_month_outlined,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$batchCount Active ${batchCount == 1 ? 'Batch' : 'Batches'}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _navy),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: openSeats > 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                openSeats > 0 ? '$openSeats Open Seats' : 'Full / Closed',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: openSeats > 0 ? _emerald : Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
        if (profile.batches.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Timings: ${profile.batches.first.startTime} - ${profile.batches.first.endTime}',
            style: const TextStyle(fontSize: 11, color: _mutedSlate),
          ),
          const SizedBox(height: 2),
          Text(
            'Days: ${profile.batches.first.days.join(', ')}',
            style: const TextStyle(fontSize: 10.5, color: _mutedSlate),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildExperienceAndRatingsSection(
    _TeacherComparisonProfile profile,
    bool isTopRated,
    bool isMostExperienced,
  ) {
    return _buildSectionCard(
      title: 'Experience & Reputation',
      icon: Icons.workspace_premium_outlined,
      isHighlighted: isTopRated || isMostExperienced,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 17, color: _accentAmber),
                    const SizedBox(width: 4),
                    Text(
                      profile.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _navy,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${profile.reviewCount} Reviews',
                  style: const TextStyle(fontSize: 11, color: _mutedSlate),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${profile.experienceYears}+ Yrs',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _navy,
                  ),
                ),
                const Text(
                  'Experience',
                  style: TextStyle(fontSize: 11, color: _mutedSlate),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInsufficientTeachersView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _brandBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.compare_arrows_rounded, size: 48, color: _brandBlue),
            ),
            const SizedBox(height: 18),
            const Text(
              'Select At Least 2 Educators',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'To perform a side-by-side commute and academic comparison, shortlist at least two teachers from the search discovery screen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _mutedSlate, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Back to Search & Shortlist'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherComparisonProfile {
  final String id;
  final String name;
  final String profileImageUrl;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final int experienceYears;
  final List<String> subjects;
  final List<String> classes;
  final List<TeacherLocationModel> locations;
  final List<TeachingBatchModel> batches;
  final double? straightLineDistanceKm;
  final double? roadDistanceKm;
  final int? estimatedTravelMinutes;

  _TeacherComparisonProfile({
    required this.id,
    required this.name,
    required this.profileImageUrl,
    required this.isVerified,
    required this.rating,
    required this.reviewCount,
    required this.experienceYears,
    required this.subjects,
    required this.classes,
    required this.locations,
    required this.batches,
    this.straightLineDistanceKm,
    this.roadDistanceKm,
    this.estimatedTravelMinutes,
  });
}