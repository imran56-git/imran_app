import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/teacher_card_widget.dart';
import '../widgets/badge_details_sheet.dart';
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
  final double _studentLat = 22.5726;
  final double _studentLng = 88.3639;

  late final Stream<QuerySnapshot> _teachersStream;
  QuerySnapshot? _lastSnapshot;
  String _selectedSort = 'best';

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _scaffoldBg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _teachersStream =
        FirebaseFirestore.instance.collection('teachers').snapshots();
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

  List> _buildActiveFilterChipsData() {
    final List> list = [];
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
        'label':
            '${(minR as num).toInt()}–${(maxR as num).toInt()} KM Radius'
      });
    }
    return list;
  }

  Widget _buildTopSummaryAndSortBar(int totalMatched) {
    final activeChips = _buildActiveFilterChipsData();
    final List> sortOptions = [
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

          if (activeData == null || activeData.docs.isEmpty) {
            return _buildNoResultsView();
          }

          final matchedDocs = activeData.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final docId = doc.id.toLowerCase();

            final String name =
                (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '')
                    .toString()
                    .toLowerCase();
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

            bool matchesId = targetId.isEmpty || docId.contains(targetId);
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
              return dA.compareTo(dB);
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

                          String distanceText = "N/A";
                          if (tLat != 0.0 && tLng != 0.0) {
                            double distance = _calculateHaversineDistance(
                                _studentLat, _studentLng, tLat, tLng);
                            distanceText = "${distance.toStringAsFixed(1)} KM";
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

                          return TeacherCardWidget(
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
                                final directDoc = await FirebaseFirestore.instance
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
                                  builder: (context) => TeacherProfileScreen(
                                    currentUserId: doc.id,
                                  ),
                                ),
                              );
                            },
                            onMapPressed: (tLat != 0.0 && tLng != 0.0)
                                ? () => _openGoogleMap(tLat, tLng, teacherName)
                                : null,
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
