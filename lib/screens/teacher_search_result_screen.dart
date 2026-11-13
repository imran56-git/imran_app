import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/google_maps_route_service.dart';
import '../services/location_service.dart';
import '../widgets/badge_details_sheet.dart';
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

class _TeacherSearchResultScreenState extends State<TeacherSearchResultScreen>
    with SingleTickerProviderStateMixin {
  double _studentLat = 22.5726;
  double _studentLng = 88.3639;
  bool _isLoadingLocation = true;

  late final Stream<QuerySnapshot> _teachersStream;
  QuerySnapshot? _lastSnapshot;
  String _selectedSort = 'best';

  bool _isStudentIdGlitch = false;
  bool _hasShownGlitchDialog = false;

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _accentAmber = Color(0xFFF59E0B);
  static const Color _scaffoldBg = Color(0xFFF8FAFC);
  static const Color _cardBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _teachersStream =
        FirebaseFirestore.instance.collection('teachers').snapshots();
    _initStudentLocation();
    _validateSearchTargetId();
  }

  Future<void> _initStudentLocation() async {
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
          _studentLat = (pos.latitude as num).toDouble();
          _studentLng = (pos.longitude as num).toDouble();
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
      // 1. Check teachers collection FIRST (doc, uid, teacherId)
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

      // If a document exists in teachers with a non-empty name, immediately confirm as valid teacher
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

      // 2. ONLY if no valid teacher document exists in teachers, check students and users
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
    } else {
      debugPrint('Could not launch Google Maps');
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

  String _extractLocationDisplay(Map<String, dynamic> data) {
    final direct =
        (data['teachingLocation'] ?? data['location'] ?? data['address'] ?? '')
            .toString()
            .trim();
    if (direct.isNotEmpty) return direct;

    if (data['locations'] is List && (data['locations'] as List).isNotEmpty) {
      final firstLoc = (data['locations'] as List).first;
      if (firstLoc is Map) {
        final addr = (firstLoc['address'] ?? '').toString().trim();
        if (addr.isNotEmpty) return addr;
      } else if (firstLoc != null) {
        final addr = firstLoc.toString().trim();
        if (addr.isNotEmpty) return addr;
      }
    }
    return 'Location N/A';
  }

  String _extractAllLocationsSearchable(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.write('${data['teachingLocation'] ?? ''} ');
    buffer.write('${data['location'] ?? ''} ');
    buffer.write('${data['address'] ?? ''} ');
    if (data['locations'] is List) {
      for (final item in (data['locations'] as List)) {
        if (item is Map) {
          buffer.write('${item['address'] ?? ''} ');
        } else if (item != null) {
          buffer.write('$item ');
        }
      }
    }
    return buffer.toString().toLowerCase();
  }

  Map<String, double> _extractCoordinates(Map<String, dynamic> data) {
    double? lat = double.tryParse(data['latitude']?.toString() ?? '');
    double? lng = double.tryParse(data['longitude']?.toString() ?? '');

    if ((lat == null || lng == null) &&
        data['locations'] is List &&
        (data['locations'] as List).isNotEmpty) {
      final firstLoc = (data['locations'] as List).first;
      if (firstLoc is Map) {
        lat ??= double.tryParse(
            (firstLoc['lat'] ?? firstLoc['latitude'])?.toString() ?? '');
        lng ??= double.tryParse(
            (firstLoc['lng'] ?? firstLoc['longitude'])?.toString() ?? '');
      }
    }

    if ((lat == null || lng == null) && data['teachingLocation'] != null) {
      final parts = data['teachingLocation'].toString().split(',');
      if (parts.length == 2) {
        lat = double.tryParse(parts[0].trim());
        lng = double.tryParse(parts[1].trim());
      }
    }

    if ((lat == null || lng == null) && data['location'] != null) {
      final parts = data['location'].toString().split(',');
      if (parts.length == 2) {
        lat = double.tryParse(parts[0].trim());
        lng = double.tryParse(parts[1].trim());
      }
    }

    return {'lat': lat ?? 0.0, 'lng': lng ?? 0.0};
  }

  int _calculateSmartMatchScore({
    required Map<String, dynamic> data,
    required double distanceKm,
    required String targetSubject,
    required String targetClass,
    required double maxRadius,
  }) {
    double score = 40.0; // Base baseline score

    // 1. Subject Relevance (up to 30 pts)
    final List<String> subjects = [];
    if (data['subjects'] is List) {
      subjects.addAll((data['subjects'] as List).map((s) => s.toString().toLowerCase()));
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

    // 2. Class / Standard Matching (up to 15 pts)
    final String teacherClass =
        (data['class'] ?? data['teachingClass'] ?? '').toString().toLowerCase();
    if (targetClass.isNotEmpty) {
      if (teacherClass.contains(targetClass)) {
        score += 15;
      }
    } else {
      score += 10;
    }

    // 3. Distance Proximity (up to 15 pts)
    if (distanceKm > 0) {
      if (distanceKm <= 5.0) {
        score += 15;
      } else if (distanceKm <= 15.0) {
        score += 10;
      } else if (distanceKm <= maxRadius) {
        score += 5;
      }
    } else {
      score += 8;
    }

    // 4. Rating & Verification (up to 10 pts)
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
    final minR = f['minRadius'];
    final maxR = f['maxRadius'];

    if (name.isNotEmpty) list.add({'label': 'Name: $name'});
    if (subject.isNotEmpty) list.add({'label': subject});
    if (location.isNotEmpty) list.add({'label': location});
    if (exp.isNotEmpty) list.add({'label': '$exp+ Yrs Exp'});
    if (minR != null && maxR != null) {
      list.add({
        'label': '${(minR as num).toInt()}–${(maxR as num).toInt()} KM Radius'
      });
    }
    return list;
  }

  Widget _buildTopSummaryAndSortBar(int totalMatched) {
    final activeChips = _buildActiveFilterChipsData();
    final List<Map<String, dynamic>> sortOptions = [
      {'key': 'best', 'label': 'Best Match', 'icon': Icons.auto_awesome_rounded},
      {'key': 'rating', 'label': 'Top Rated', 'icon': Icons.star_rounded},
      {
        'key': 'experience',
        'label': 'Most Experienced',
        'icon': Icons.workspace_premium_rounded
      },
      {'key': 'distance', 'label': 'Nearest', 'icon': Icons.near_me_rounded},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      '$totalMatched Educator${totalMatched == 1 ? '' : 's'} Found',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _accentBlue,
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 15, color: _brandBlue),
                      SizedBox(width: 4),
                      Text(
                        'Modify Filters',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _brandBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 13, color: Color(0xFF0D9488)),
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
                          horizontal: 12, vertical: 6),
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
                          const SizedBox(width: 5),
                          Text(
                            opt['label'] as String,
                            style: TextStyle(
                              fontSize: 11.8,
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
    final double minRadius =
        double.tryParse(filters['minRadius']?.toString() ?? '0.0') ?? 0.0;
    final double maxRadius =
        double.tryParse(filters['maxRadius']?.toString() ?? '500.0') ?? 500.0;

    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              'Matching Teachers',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17.5,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              'Verified Educators & Subject Specialists',
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
                Color(0xFF1E3A8A),
                _brandBlue,
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

          final matchedDocs = activeData.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            if (_isStudentIdGlitch) return false;

            final String rawName =
                (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '')
                    .toString();
            if (rawName.trim().isEmpty) return false;

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

            bool matchesRadius = true;
            final coords = _extractCoordinates(data);
            double tLat = coords['lat']!;
            double tLng = coords['lng']!;

            if (targetId.isEmpty && tLat != 0.0 && tLng != 0.0) {
              double distance = _calculateHaversineDistance(
                  _studentLat, _studentLng, tLat, tLng);
              matchesRadius = distance >= minRadius && distance <= maxRadius;
            }

            return matchesId &&
                matchesName &&
                matchesLocation &&
                matchesSubject &&
                matchesExperience &&
                matchesRadius;
          }).toList();

          matchedDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>? ?? {};
            final bData = b.data() as Map<String, dynamic>? ?? {};

            final cA = _extractCoordinates(aData);
            final cB = _extractCoordinates(bData);
            final double dA = (cA['lat'] != 0.0 && cA['lng'] != 0.0)
                ? _calculateHaversineDistance(
                    _studentLat, _studentLng, cA['lat']!, cA['lng']!)
                : 999999.0;
            final double dB = (cB['lat'] != 0.0 && cB['lng'] != 0.0)
                ? _calculateHaversineDistance(
                    _studentLat, _studentLng, cB['lat']!, cB['lng']!)
                : 999999.0;

            if (_selectedSort == 'rating') {
              final double rA = double.tryParse(
                      (aData['averageRating'] ?? aData['rating'] ?? '0')
                          .toString()) ??
                  0.0;
              final double rB = double.tryParse(
                      (bData['averageRating'] ?? bData['rating'] ?? '0')
                          .toString()) ??
                  0.0;
              return rB.compareTo(rA);
            }

            if (_selectedSort == 'experience') {
              return _parseExperienceYears(bData)
                  .compareTo(_parseExperienceYears(aData));
            }

            if (_selectedSort == 'distance') {
              return dA.compareTo(dB);
            }

            // Default 'best' sort: Dynamic Smart Match Score
            final scoreA = _calculateSmartMatchScore(
              data: aData,
              distanceKm: dA,
              targetSubject: targetSubject,
              targetClass: targetClass,
              maxRadius: maxRadius,
            );
            final scoreB = _calculateSmartMatchScore(
              data: bData,
              distanceKm: dB,
              targetSubject: targetSubject,
              targetClass: targetClass,
              maxRadius: maxRadius,
            );

            if (scoreA != scoreB) {
              return scoreB.compareTo(scoreA);
            }

            final bool vA = aData['isVerified'] == true;
            final bool vB = bData['isVerified'] == true;
            if (vA != vB) return vB ? 1 : -1;

            final double rA = double.tryParse(
                    (aData['averageRating'] ?? aData['rating'] ?? '0')
                        .toString()) ??
                0.0;
            final double rB = double.tryParse(
                    (bData['averageRating'] ?? bData['rating'] ?? '0')
                        .toString()) ??
                0.0;
            return rB.compareTo(rA);
          });

          return Column(
            children: [
              _buildTopSummaryAndSortBar(matchedDocs.length),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: matchedDocs.isEmpty
                    ? _buildNoResultsView()
                    : ListView.builder(
                        key: const PageStorageKey<String>(
                            'teacher_search_results_list'),
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 28),
                        physics: const BouncingScrollPhysics(),
                        itemCount: matchedDocs.length,
                        itemBuilder: (context, index) {
                          final doc = matchedDocs[index];
                          final data =
                              doc.data() as Map<String, dynamic>? ?? {};

                          final coords = _extractCoordinates(data);
                          double tLat = coords['lat']!;
                          double tLng = coords['lng']!;

                          double distanceKm = -1.0;
                          String distanceText = "N/A";
                          if (tLat != 0.0 && tLng != 0.0) {
                            distanceKm = _calculateHaversineDistance(
                                _studentLat, _studentLng, tLat, tLng);
                            distanceText = "${distanceKm.toStringAsFixed(1)} KM";
                          }

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
                              _extractLocationDisplay(data);

                          final double ratingVal = double.tryParse(
                                  (data['averageRating'] ??
                                          data['rating'] ??
                                          '0.0')
                                      .toString()) ??
                              0.0;

                          final int matchScore = _calculateSmartMatchScore(
                            data: data,
                            distanceKm: distanceKm,
                            targetSubject: targetSubject,
                            targetClass: targetClass,
                            maxRadius: maxRadius,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_primaryNavy, _brandBlue],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primaryNavy.withOpacity(0.12),
                                        blurRadius: 6,
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
                                        size: 13,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '$matchScore% Smart Match',
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
                                experienceYears: _parseExperienceYears(data),
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
                                          if (participants.contains(teacherId)) {
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
                              const SizedBox(height: 12),
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
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _brandBlue.withOpacity(0.12),
                    _accentBlue.withOpacity(0.05),
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
              "No Matching Educators Found",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "We couldn't find any teacher matching your exact filters and radius settings. Try broadening your search criteria or increasing the distance range.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.2,
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
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text(
                "Adjust Search Filters",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}