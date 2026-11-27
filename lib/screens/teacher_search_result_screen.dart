import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_service.dart';
import '../widgets/teacher_card_widget.dart';
import 'chat_screen.dart';
import 'teacher_profile_screen.dart';

class TeacherSearchResultScreen extends StatefulWidget {
  final Map<String, dynamic> filters;

  const TeacherSearchResultScreen({super.key, required this.filters});

  @override
  State<TeacherSearchResultScreen> createState() =>
      _TeacherSearchResultScreenState();
}

class _TeacherSearchResultScreenState extends State<TeacherSearchResultScreen> {
  double _searchLat = 22.5726;
  double _searchLng = 88.3639;
  bool _isLoadingLocation = true;

  late final Stream<QuerySnapshot> _teachersStream;
  QuerySnapshot? _lastSnapshot;
  String _selectedSort = 'best';

  bool _isStudentIdGlitch = false;
  bool _hasShownGlitchDialog = false;

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF133E68);
  static const Color _secondaryBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _accentAmber = Color(0xFFFFB300);
  static const Color _scaffoldBg = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _teachersStream =
        FirebaseFirestore.instance.collection('teachers').snapshots();
    _setupSearchCoordinates();
    _validateSearchTargetId();
  }

  Future<void> _setupSearchCoordinates() async {
    final passedLat = (widget.filters['latitude'] as num?)?.toDouble();
    final passedLng = (widget.filters['longitude'] as num?)?.toDouble();

    if (passedLat != null && passedLng != null) {
      if (mounted) {
        setState(() {
          _searchLat = passedLat;
          _searchLng = passedLng;
          _isLoadingLocation = false;
        });
      }
      return;
    }

    try {
      dynamic pos;
      try {
        pos = await LocationService.getCurrentLocation();
      } catch (_) {
        final dynamic locService = LocationService();
        pos = await locService.getCurrentLocation();
      }
      if (pos != null && mounted) {
        setState(() {
          _searchLat = (pos.latitude as num).toDouble();
          _searchLng = (pos.longitude as num).toDouble();
          _isLoadingLocation = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _validateSearchTargetId() async {
    final String targetId =
        (widget.filters['teacherId'] ?? '').toString().trim();
    if (targetId.isEmpty) return;

    try {
      Map<String, dynamic>? teacherData;

      final teacherDoc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(targetId)
          .get();

      if (teacherDoc.exists) {
        teacherData = teacherDoc.data();
      } else {
        final uidQuery = await FirebaseFirestore.instance
            .collection('teachers')
            .where('uid', isEqualTo: targetId)
            .limit(1)
            .get();
        if (uidQuery.docs.isNotEmpty) {
          teacherData = uidQuery.docs.first.data();
        } else {
          final teacherIdQuery = await FirebaseFirestore.instance
              .collection('teachers')
              .where('teacherId', isEqualTo: targetId)
              .limit(1)
              .get();
          if (teacherIdQuery.docs.isNotEmpty) {
            teacherData = teacherIdQuery.docs.first.data();
          }
        }
      }

      if (teacherData != null) {
        final teacherName = (teacherData['name'] ??
                teacherData['fullName'] ??
                teacherData['displayName'] ??
                '')
            .toString()
            .trim();
        if (teacherName.isNotEmpty) {
          if (mounted) {
            setState(() {
              _isStudentIdGlitch = false;
            });
          }
          return;
        }
      }

      bool isStudentAccount = false;

      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(targetId)
          .get();

      if (studentDoc.exists) {
        isStudentAccount = true;
      } else {
        final studentUidQuery = await FirebaseFirestore.instance
            .collection('students')
            .where('uid', isEqualTo: targetId)
            .limit(1)
            .get();
        if (studentUidQuery.docs.isNotEmpty) {
          isStudentAccount = true;
        } else {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(targetId)
              .get();
          if (userDoc.exists) {
            final role =
                (userDoc.data()?['role'] ?? '').toString().toLowerCase();
            if (role == 'student') {
              isStudentAccount = true;
            }
          } else {
            final userUidQuery = await FirebaseFirestore.instance
                .collection('users')
                .where('uid', isEqualTo: targetId)
                .limit(1)
                .get();
            if (userUidQuery.docs.isNotEmpty) {
              final role = (userUidQuery.docs.first.data()['role'] ?? '')
                  .toString()
                  .toLowerCase();
              if (role == 'student') {
                isStudentAccount = true;
              }
            }
          }
        }
      }

      if (isStudentAccount) {
        if (mounted) {
          setState(() {
            _isStudentIdGlitch = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_hasShownGlitchDialog && mounted) {
              _hasShownGlitchDialog = true;
              _showInvalidEducatorDialog();
            }
          });
        }
        return;
      }
    } catch (_) {}
  }

  void _showInvalidEducatorDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Invalid Educator Dialog',
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (dialogCtx, anim1, anim2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: FadeTransition(
              opacity: anim1,
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFFFEE2E2), width: 1.5),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFFDC2626),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Invalid Educator ID',
                        style: TextStyle(
                          color: _primaryNavy,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'The entered ID corresponds to a Student account. This discovery engine is exclusively designed for finding verified teachers and institutes.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
                actionsPadding:
                    const EdgeInsets.only(left: 18, right: 18, bottom: 18),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brandBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text(
                        'Search Again',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _calculateHaversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0;

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180.0);
  }

  Future<void> _openGoogleMap(
      double lat, double lng, String teacherName) async {
    final Uri googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  String _getChatRoomId(String teacherId, String studentId) {
    return "${teacherId}_$studentId";
  }

  int _parseExperienceYears(Map<String, dynamic> data) {
    final raw = data['experience'] ??
        data['teachingExperience'] ??
        data['experienceYears'] ??
        0;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final match = RegExp(r'\d+').firstMatch(raw.toString());
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  int _getBadgeTierWeight(String? badgeType, bool isVerified) {
    final clean = (badgeType ?? '').trim().toLowerCase();
    if (clean.contains('diamond')) return 5;
    if (clean.contains('platinum')) return 4;
    if (clean.contains('gold')) return 3;
    if (clean.contains('silver')) return 2;
    if (clean.contains('bronze')) return 1;
    if (isVerified) return 1;
    return 0;
  }

  Map<String, dynamic> _extractNearestTeachingHub(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> hubs = [];

    double? topLat = double.tryParse(data['latitude']?.toString() ?? '');
    double? topLng = double.tryParse(data['longitude']?.toString() ?? '');
    String topAddr =
        (data['teachingLocation'] ?? data['location'] ?? data['address'] ?? '')
            .toString()
            .trim();
    if (topLat != null && topLng != null) {
      hubs.add({
        'lat': topLat,
        'lng': topLng,
        'address': topAddr.isNotEmpty ? topAddr : 'Main Hub',
      });
    }

    void parseLocationCollection(dynamic rawList) {
      if (rawList is! List) return;
      for (final item in rawList) {
        if (item is Map) {
          final lat = double.tryParse(
              (item['latitude'] ?? item['lat'])?.toString() ?? '');
          final lng = double.tryParse(
              (item['longitude'] ?? item['lng'])?.toString() ?? '');
          final addr = (item['address'] ??
                  item['fullAddress'] ??
                  item['location'] ??
                  item['name'] ??
                  '')
              .toString()
              .trim();
          if (lat != null && lng != null) {
            hubs.add({
              'lat': lat,
              'lng': lng,
              'address': addr.isNotEmpty ? addr : 'Teaching Hub',
            });
          }
        } else if (item is String) {
          final parts = item.split(',');
          if (parts.length == 2) {
            final lat = double.tryParse(parts[0].trim());
            final lng = double.tryParse(parts[1].trim());
            if (lat != null && lng != null) {
              hubs.add({
                'lat': lat,
                'lng': lng,
                'address': item.trim(),
              });
            }
          }
        }
      }
    }

    parseLocationCollection(data['teachingLocations']);
    parseLocationCollection(data['locations']);
    parseLocationCollection(data['teachingAreas']);

    if (topAddr.contains(',')) {
      final parts = topAddr.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          hubs.add({
            'lat': lat,
            'lng': lng,
            'address': topAddr,
          });
        }
      }
    }

    if (hubs.isEmpty) {
      return {
        'lat': 0.0,
        'lng': 0.0,
        'address': topAddr.isNotEmpty ? topAddr : 'Location N/A',
        'distanceKm': -1.0,
      };
    }

    Map<String, dynamic> nearestHub = hubs.first;
    double minDistance = double.infinity;

    for (final hub in hubs) {
      final double lat = hub['lat'] as double;
      final double lng = hub['lng'] as double;
      final double dist =
          _calculateHaversineDistance(_searchLat, _searchLng, lat, lng);
      if (dist < minDistance) {
        minDistance = dist;
        nearestHub = {
          'lat': lat,
          'lng': lng,
          'address': hub['address'],
          'distanceKm': dist,
        };
      }
    }

    return nearestHub;
  }

  String _extractAllLocationsSearchable(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.write('${data['teachingLocation'] ?? ''} ');
    buffer.write('${data['location'] ?? ''} ');
    buffer.write('${data['address'] ?? ''} ');

    void appendList(dynamic list) {
      if (list is List) {
        for (final item in list) {
          if (item is Map) {
            buffer.write(
                '${item['address'] ?? item['fullAddress'] ?? item['name'] ?? ''} ');
          } else if (item != null) {
            buffer.write('$item ');
          }
        }
      }
    }

    appendList(data['locations']);
    appendList(data['teachingLocations']);
    appendList(data['teachingAreas']);

    return buffer.toString().toLowerCase();
  }

  int _calculateSmartMatchScore({
    required Map<String, dynamic> data,
    required double distanceKm,
    required String targetSubject,
    required String targetClass,
    required double? maxRadius,
  }) {
    double score = 40.0;

    final List<String> subjects = [];
    if (data['subjects'] is List) {
      subjects.addAll((data['subjects'] as List)
          .map((s) => s.toString().toLowerCase()));
    } else if (data['subjects'] is String) {
      subjects.add(data['subjects'].toString().toLowerCase());
    }

    if (targetSubject.isNotEmpty) {
      if (subjects.any((s) => s == targetSubject)) {
        score += 30;
      } else if (subjects.any((s) => s.contains(targetSubject))) {
        score += 20;
      }
    } else {
      score += 20;
    }

    final String teacherClass =
        (data['class'] ?? data['teachingClass'] ?? '').toString().toLowerCase();
    if (targetClass.isNotEmpty) {
      if (teacherClass.contains(targetClass)) {
        score += 15;
      }
    } else {
      score += 10;
    }

    if (distanceKm >= 0) {
      if (distanceKm <= 5.0) {
        score += 15;
      } else if (distanceKm <= 15.0) {
        score += 10;
      } else if (maxRadius != null && distanceKm <= maxRadius) {
        score += 5;
      } else {
        score += 3;
      }
    } else {
      score += 8;
    }

    final double rating = double.tryParse(
            (data['averageRating'] ?? data['rating'] ?? '0.0').toString()) ??
        0.0;
    if (rating >= 4.5) {
      score += 5;
    } else if (rating >= 4.0) {
      score += 3;
    }

    final bool isVerified =
        data['isVerified'] == true || data['status'] == 'approved';
    if (isVerified) {
      score += 5;
    }

    return score.clamp(0, 100).toInt();
  }

  String _formatTeacherCount(int count) {
    final str = count.toString();
    final regExp = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return str.replaceAll(regExp, ',');
  }

  List<Map<String, String>> _buildActiveFilterChipsData() {
    final List<Map<String, String>> list = [];
    final f = widget.filters;

    final id = (f['teacherId'] ?? '').toString().trim();
    if (id.isNotEmpty) {
      list.add({'label': 'ID: $id'});
      return list;
    }

    final name = (f['name'] ?? '').toString().trim();
    final subject = (f['subject'] ?? '').toString().trim();
    final location = (f['location'] ?? '').toString().trim();
    final exp = (f['experience'] ?? '').toString().trim();
    final maxR = f['maxRadius'];

    if (name.isNotEmpty) list.add({'label': 'Name: $name'});
    if (subject.isNotEmpty) list.add({'label': subject});
    if (location.isNotEmpty) list.add({'label': location});
    if (exp.isNotEmpty) list.add({'label': '$exp+ Yrs Exp'});
    if (maxR != null) {
      list.add({'label': 'Within ${(maxR as num).toInt()} KM'});
    } else {
      list.add({'label': 'Any Distance'});
    }
    return list;
  }

  Widget _buildTopSummaryAndSortBar(int totalMatched) {
    final activeChips = _buildActiveFilterChipsData();
    final List<Map<String, dynamic>> sortOptions = [
      {'key': 'best', 'label': 'Best Match', 'icon': Icons.auto_awesome_rounded},
      {'key': 'distance', 'label': 'Nearest', 'icon': Icons.near_me_rounded},
      {
        'key': 'experience',
        'label': 'Most Experienced',
        'icon': Icons.workspace_premium_rounded
      },
      {'key': 'rating', 'label': 'Top Rated', 'icon': Icons.star_rounded},
    ];

    final formattedCount = _formatTeacherCount(totalMatched);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryNavy, _secondaryBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _primaryNavy.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _accentAmber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: _accentAmber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$formattedCount Teacher${totalMatched == 1 ? '' : 's'} Available',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          totalMatched == 0
                              ? 'No matches in this search'
                              : 'Complete unfiltered coverage for your area',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded,
                            size: 14, color: _accentAmber),
                        SizedBox(width: 4),
                        Text(
                          'Filter',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (activeChips.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: activeChips.map((chip) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 13,
                          color: Color(0xFF0D9488),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          chip['label']!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: sortOptions.map((opt) {
                final bool isSelected = _selectedSort == opt['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedSort = opt['key'] as String);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [_primaryNavy, _brandBlue],
                              )
                            : null,
                        color: isSelected ? null : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? _brandBlue
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            opt['icon'] as IconData,
                            size: 14,
                            color: isSelected
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            opt['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final filters = widget.filters;

    final String targetId =
        (filters['teacherId'] ?? '').toString().trim().toLowerCase();
    final String targetName =
        (filters['name'] ?? '').toString().trim().toLowerCase();
    final String targetSubject =
        (filters['subject'] ?? '').toString().trim().toLowerCase();
    final String targetClass =
        (filters['class'] ?? filters['grade'] ?? '').toString().trim().toLowerCase();
    final String targetLocation =
        (filters['location'] ?? '').toString().trim().toLowerCase();

    final int minExperience =
        int.tryParse(filters['experience']?.toString() ?? '0') ?? 0;
    final double? maxRadius = (filters['maxRadius'] as num?)?.toDouble();

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              'Available Teachers',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              'Verified Educators Across All Local Hubs',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: _primaryNavy,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primaryNavy,
                Color(0xFF133E68),
                _secondaryBlue,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 19, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _teachersStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _lastSnapshot = snapshot.data;
          }
          final activeData = snapshot.data ?? _lastSnapshot;

          if (activeData == null &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                  color: _brandBlue, strokeWidth: 3),
            );
          }

          if (snapshot.hasError && activeData == null) {
            return Center(
              child: Text(
                'Error fetching teachers: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (_isStudentIdGlitch || activeData == null || activeData.docs.isEmpty) {
            return _buildNoResultsView();
          }

          final List<Map<String, dynamic>> processedTeachers = [];

          for (final doc in activeData.docs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            if (_isStudentIdGlitch) continue;

            final String rawName =
                (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '')
                    .toString();
            if (rawName.trim().isEmpty) continue;

            final docId = doc.id.toLowerCase();
            final fieldUid = (data['uid'] ?? data['teacherId'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

            final String name = rawName.toLowerCase();
            final String locationSearchable =
                _extractAllLocationsSearchable(data);

            List<String> subjects = [];
            if (data['subjects'] is List) {
              subjects = (data['subjects'] as List)
                  .map((s) => s.toString().toLowerCase())
                  .toList();
            } else if (data['subjects'] is String) {
              subjects = [data['subjects'].toString().toLowerCase()];
            }

            final int exp = _parseExperienceYears(data);

            bool matchesId = targetId.isEmpty ||
                docId.contains(targetId) ||
                (fieldUid.isNotEmpty && fieldUid.contains(targetId));
            bool matchesName = targetName.isEmpty || name.contains(targetName);
            bool matchesLocation = targetLocation.isEmpty ||
                locationSearchable.contains(targetLocation);
            bool matchesSubject = targetSubject.isEmpty ||
                subjects.any((s) => s.contains(targetSubject));
            bool matchesExperience = exp >= minExperience;

            final hubInfo = _extractNearestTeachingHub(data);
            final double hubDistance = hubInfo['distanceKm'] as double;

            bool matchesRadius = true;
            if (targetId.isEmpty && maxRadius != null) {
              if (hubDistance >= 0) {
                matchesRadius = hubDistance <= maxRadius;
              }
            }

            if (matchesId &&
                matchesName &&
                matchesLocation &&
                matchesSubject &&
                matchesExperience &&
                matchesRadius) {
              final int smartScore = _calculateSmartMatchScore(
                data: data,
                distanceKm: hubDistance,
                targetSubject: targetSubject,
                targetClass: targetClass,
                maxRadius: maxRadius,
              );

              final bool isVerified = data['isVerified'] == true ||
                  data['status'] == 'approved';
              final String? badgeType = data['highestBadgeType']?.toString();
              final int badgeWeight = _getBadgeTierWeight(badgeType, isVerified);

              final double rating = double.tryParse(
                      (data['averageRating'] ?? data['rating'] ?? '0.0')
                          .toString()) ??
                  0.0;

              processedTeachers.add({
                'doc': doc,
                'data': data,
                'hubLat': hubInfo['lat'] as double,
                'hubLng': hubInfo['lng'] as double,
                'hubAddress': hubInfo['address'] as String,
                'distanceKm': hubDistance,
                'smartScore': smartScore,
                'badgeWeight': badgeWeight,
                'rating': rating,
                'experience': exp,
              });
            }
          }

          processedTeachers.sort((a, b) {
            if (_selectedSort == 'distance') {
              final double dA = (a['distanceKm'] as double) >= 0
                  ? (a['distanceKm'] as double)
                  : 999999.0;
              final double dB = (b['distanceKm'] as double) >= 0
                  ? (b['distanceKm'] as double)
                  : 999999.0;
              final comp = dA.compareTo(dB);
              if (comp != 0) return comp;
              return (b['smartScore'] as int).compareTo(a['smartScore'] as int);
            }

            if (_selectedSort == 'experience') {
              final comp = (b['experience'] as int)
                  .compareTo(a['experience'] as int);
              if (comp != 0) return comp;
              return (b['rating'] as double).compareTo(a['rating'] as double);
            }

            if (_selectedSort == 'rating') {
              final comp =
                  (b['rating'] as double).compareTo(a['rating'] as double);
              if (comp != 0) return comp;
              return (b['smartScore'] as int).compareTo(a['smartScore'] as int);
            }

            final int badgeComp =
                (b['badgeWeight'] as int).compareTo(a['badgeWeight'] as int);
            if (badgeComp != 0) return badgeComp;

            final int scoreComp =
                (b['smartScore'] as int).compareTo(a['smartScore'] as int);
            if (scoreComp != 0) return scoreComp;

            final int ratingComp =
                (b['rating'] as double).compareTo(a['rating'] as double);
            if (ratingComp != 0) return ratingComp;

            final double dA = (a['distanceKm'] as double) >= 0
                ? (a['distanceKm'] as double)
                : 999999.0;
            final double dB = (b['distanceKm'] as double) >= 0
                ? (b['distanceKm'] as double)
                : 999999.0;
            return dA.compareTo(dB);
          });

          return Column(
            children: [
              _buildTopSummaryAndSortBar(processedTeachers.length),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: processedTeachers.isEmpty
                    ? _buildNoResultsView()
                    : ListView.builder(
                        key: const PageStorageKey<String>(
                            'teacher_search_results_list'),
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 32),
                        physics: const BouncingScrollPhysics(),
                        itemCount: processedTeachers.length,
                        itemBuilder: (context, index) {
                          final item = processedTeachers[index];
                          final doc = item['doc'] as QueryDocumentSnapshot;
                          final data = item['data'] as Map<String, dynamic>;

                          final double tLat = item['hubLat'] as double;
                          final double tLng = item['hubLng'] as double;
                          final double dist = item['distanceKm'] as double;
                          final String distanceText =
                              dist >= 0 ? '${dist.toStringAsFixed(1)} KM' : 'N/A';

                          List<String> subjectsList = [];
                          if (data['subjects'] is List) {
                            subjectsList = List<String>.from(
                                data['subjects'].map((x) => x.toString()));
                          } else if (data['subjects'] is String) {
                            subjectsList = [data['subjects'].toString()];
                          }
                          final String subjectText = subjectsList.isNotEmpty
                              ? subjectsList.join(', ')
                              : 'General';

                          final String teacherName = (data['name'] ??
                                  data['fullName'] ??
                                  data['displayName'] ??
                                  'Unknown Teacher')
                              .toString();

                          final String profilePic = (data['profileUrl'] ??
                                  data['profileImageUrl'] ??
                                  data['photoUrl'] ??
                                  data['profilePic'] ??
                                  '')
                              .toString();

                          final bool isVerified = data['isVerified'] == true ||
                              data['status'] == 'approved';
                          final String? highestBadgeType =
                              data['highestBadgeType']?.toString();

                          final String locationDisplay =
                              item['hubAddress'] as String;
                          final double ratingVal = item['rating'] as double;
                          final int matchScore = item['smartScore'] as int;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 4, right: 4, bottom: 6),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: _primaryNavy,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '#${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 9, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                _primaryNavy,
                                                _secondaryBlue
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _primaryNavy
                                                    .withOpacity(0.12),
                                                blurRadius: 5,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.auto_awesome,
                                                color: Color(0xFFFBBF24),
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$matchScore% Match',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (dist >= 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFFBFDBFE),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.near_me_rounded,
                                              size: 11,
                                              color: _accentBlue,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              distanceText,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: _accentBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              TeacherCardWidget(
                                key: ValueKey('teacher_card_${doc.id}'),
                                teacherId: doc.id,
                                name: teacherName,
                                subject: subjectText,
                                profileImageUrl: profilePic,
                                latitude: tLat,
                                longitude: tLng,
                                studentCount: data['studentCount'] is int
                                    ? data['studentCount']
                                    : int.tryParse(data['studentCount']
                                                ?.toString() ??
                                            '0') ??
                                        0,
                                experienceYears: item['experience'] as int,
                                followersCount: data['followersCount'] is int
                                    ? data['followersCount']
                                    : int.tryParse(data['followersCount']
                                                ?.toString() ??
                                            '0') ??
                                        0,
                                rating: ratingVal,
                                locationText: locationDisplay,
                                calculatedDistance: distanceText,
                                isVerified: isVerified,
                                highestBadgeType: highestBadgeType,
                                onChatPressed: () async {
                                  if (currentUserId.isEmpty) return;

                                  final String teacherId = doc.id;
                                  String targetChatRoomId =
                                      _getChatRoomId(teacherId, currentUserId);

                                  try {
                                    final directDoc = await FirebaseFirestore
                                        .instance
                                        .collection('chats')
                                        .doc(targetChatRoomId)
                                        .get();

                                    if (!directDoc.exists) {
                                      final reverseDoc = await FirebaseFirestore
                                          .instance
                                          .collection('chats')
                                          .doc('${currentUserId}_$teacherId')
                                          .get();

                                      if (reverseDoc.exists) {
                                        targetChatRoomId =
                                            '${currentUserId}_$teacherId';
                                      } else {
                                        final query = await FirebaseFirestore
                                            .instance
                                            .collection('chats')
                                            .where('participants',
                                                arrayContains: currentUserId)
                                            .get();

                                        for (final cDoc in query.docs) {
                                          final participants =
                                              (cDoc.data()['participants']
                                                      as List?) ??
                                                  [];
                                          if (participants
                                              .contains(teacherId)) {
                                            targetChatRoomId = cDoc.id;
                                            break;
                                          }
                                        }
                                      }
                                    }
                                  } catch (_) {}

                                  if (!context.mounted) return;

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        chatRoomId: targetChatRoomId,
                                        receiverId: doc.id,
                                        receiverName: teacherName,
                                        receiverProfilePic: profilePic,
                                        currentUserId: currentUserId,
                                        isTeacher: false,
                                      ),
                                    ),
                                  );
                                },
                                onProfilePressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          TeacherProfileScreen(
                                        currentUserId: doc.id,
                                      ),
                                    ),
                                  );
                                },
                                onMapPressed: (tLat != 0.0 && tLng != 0.0)
                                    ? () => _openGoogleMap(
                                        tLat, tLng, teacherName)
                                    : null,
                              ),
                              const SizedBox(height: 14),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _brandBlue.withOpacity(0.12),
                    _accentBlue.withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 42,
                color: _brandBlue,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Matching Educators Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We could not find any teachers matching your criteria. Try widening your radius, removing specific filters, or selecting Any Distance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF64748B),
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text(
                'Adjust Search Filters',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}