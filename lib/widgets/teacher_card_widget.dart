import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'image_viewer.dart';
import 'teacher_badge_widget.dart';

class TeacherCardWidget extends StatelessWidget {
  final String teacherId;
  final String name;
  final String? tuitionName;
  final String subject;
  final String profileImageUrl;
  final double latitude;
  final double longitude;
  final int studentCount;
  final int experienceYears;
  final int followersCount;
  final double rating;
  final String locationText;
  final String calculatedDistance;
  final String? highestBadgeType;
  final bool isVerified;
  final VoidCallback onChatPressed;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onMapPressed;

  const TeacherCardWidget({
    super.key,
    required this.teacherId,
    required this.name,
    this.tuitionName,
    required this.subject,
    required this.profileImageUrl,
    required this.latitude,
    required this.longitude,
    required this.studentCount,
    required this.experienceYears,
    required this.followersCount,
    required this.rating,
    required this.locationText,
    required this.calculatedDistance,
    this.highestBadgeType,
    this.isVerified = false,
    required this.onChatPressed,
    this.onProfilePressed,
    this.onMapPressed,
  });

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentTeal = Color(0xFF0F766E);

  void _openFullImage(BuildContext context, String resolvedImageUrl) {
    final String subtitleText =
        (tuitionName != null && tuitionName!.trim().isNotEmpty)
            ? tuitionName!.trim()
            : subject.trim();

    ImageViewer.open(
      context,
      imageUrl: resolvedImageUrl,
      title: name,
      subtitle: subtitleText,
      heroTag: 'teacher_avatar_$teacherId',
    );
  }

  bool get _shouldShowBadge {
    return isVerified ||
        (highestBadgeType != null && highestBadgeType!.isNotEmpty);
  }

  String get _effectiveBadgeType {
    if (highestBadgeType != null && highestBadgeType!.isNotEmpty) {
      return highestBadgeType!;
    }
    return 'verified';
  }

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'T';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  List<String> _parseSubjectPills() {
    if (subject.trim().isEmpty) return ['General'];
    final parts = subject
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? ['General'] : parts;
  }

  String _pickFirstValidUrl(Map<String, dynamic>? data) {
    final candidates = [
      profileImageUrl,
      data?['profileImageUrl'],
      data?['photoUrl'],
      data?['profileUrl'],
      data?['profilePic'],
    ];
    for (final c in candidates) {
      final str = (c ?? '').toString().trim();
      if (str.startsWith('http://') || str.startsWith('https://')) {
        return str;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final subjectPills = _parseSubjectPills();
    final List<String> visibleSubjects = subjectPills.take(3).toList();
    final int extraSubjectCount =
        subjectPills.length > 3 ? subjectPills.length - 3 : 0;

    return StreamBuilder<DocumentSnapshot>>(
      stream: teacherId.trim().isNotEmpty
          ? FirebaseFirestore.instance
              .collection('teachers')
              .doc(teacherId)
              .snapshots()
          : const Stream.empty(),
      builder: (context, teacherSnap) {
        final liveTeacherData = teacherSnap.data?.data();
        final String resolvedImageUrl = _pickFirstValidUrl(liveTeacherData);
        final String resolvedTuition =
            (tuitionName != null && tuitionName!.trim().isNotEmpty)
                ? tuitionName!.trim()
                : (liveTeacherData?['institute'] ?? '').toString().trim();

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _shouldShowBadge
                  ? const Color(0xFFBFDBFE)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryNavy.withOpacity(0.045),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onProfilePressed,
                splashColor: _brandBlue.withOpacity(0.04),
                highlightColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Header: Avatar + Name + Badges + Map Action
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _openFullImage(context, resolvedImageUrl),
                            child: Hero(
                              tag: 'teacher_avatar_$teacherId',
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: _shouldShowBadge
                                            ? [
                                                const Color(0xFF1E4C7A),
                                                const Color(0xFF38BDF8),
                                              ]
                                            : [
                                                const Color(0xFFCBD5E1),
                                                const Color(0xFF94A3B8),
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundColor:
                                            const Color(0xFFEFF6FF),
                                        backgroundImage:
                                            resolvedImageUrl.isNotEmpty
                                                ? CachedNetworkImageProvider(
                                                    resolvedImageUrl)
                                                : null,
                                        child: resolvedImageUrl.isEmpty
                                            ? Text(
                                                _getInitials(name),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 19,
                                                  color: _brandBlue,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (_shouldShowBadge)
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: TeacherBadgeWidget(
                                        badgeType: _effectiveBadgeType,
                                        style: BadgeStyle.iconOnly,
                                        iconSize: 18,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 17,
                                                    color: _primaryNavy,
                                                    letterSpacing: -0.3,
                                                  ),
                                                ),
                                              ),
                                              if (_shouldShowBadge) ...[
                                                const SizedBox(width: 6),
                                                TeacherBadgeWidget(
                                                  badgeType:
                                                      _effectiveBadgeType,
                                                  style: BadgeStyle.compact,
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (resolvedTuition.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.domain_rounded,
                                                  size: 13.5,
                                                  color: _brandBlue,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    resolvedTuition,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: _brandBlue,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12.2,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (onMapPressed != null) ...[
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: 'Open in Google Maps',
                                        child: Material(
                                          color: const Color(0xFFF0FDF4),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              onMapPressed!();
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color:
                                                      const Color(0xFFBBF7D0),
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.map_rounded,
                                                color: _accentTeal,
                                                size: 19,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Subject Pill Badges
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    ...visibleSubjects.map(
                                      (sub) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 3.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFFBFDBFE),
                                          ),
                                        ),
                                        child: Text(
                                          sub,
                                          style: const TextStyle(
                                            color: Color(0xFF1E3A8A),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (extraSubjectCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '+$extraSubjectCount more',
                                          style: const TextStyle(
                                            color: Color(0xFF475569),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Location + Experience Row
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      color: Color(0xFFEF4444),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        locationText.isNotEmpty
                                            ? locationText
                                            : 'Location N/A',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F3FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.workspace_premium_rounded,
                                            size: 12,
                                            color: Color(0xFF7C3AED),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            "$experienceYears Yrs Exp.",
                                            style: const TextStyle(
                                              color: Color(0xFF6D28D9),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 4-Column Analytics Dock (Live Followers & Accepted Students)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 11,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMetaInfoItem(
                              Icons.near_me_rounded,
                              calculatedDistance.isNotEmpty
                                  ? calculatedDistance
                                  : 'N/A',
                              "Distance",
                              iconColor: const Color(0xFFEA580C),
                            ),
                            _buildMetaInfoDivider(),
                            _buildMetaInfoItem(
                              Icons.star_rounded,
                              rating > 0 ? rating.toStringAsFixed(1) : 'New',
                              "Rating",
                              iconColor: const Color(0xFFF59E0B),
                            ),
                            _buildMetaInfoDivider(),
                            StreamBuilder<QuerySnapshot>(
                              stream: teacherId.trim().isNotEmpty
                                  ? FirebaseFirestore.instance
                                      .collection('teachers')
                                      .doc(teacherId)
                                      .collection('followers')
                                      .snapshots()
                                  : const Stream.empty(),
                              builder: (context, fSnap) {
                                final int safeFallbackFollowers =
                                    followersCount < 0 ? 0 : followersCount;
                                final int displayFollowers = fSnap.hasData
                                    ? fSnap.data!.docs.length
                                    : safeFallbackFollowers;
                                return _buildMetaInfoItem(
                                  Icons.people_alt_rounded,
                                  "$displayFollowers",
                                  "Followers",
                                  iconColor: const Color(0xFF7C3AED),
                                );
                              },
                            ),
                            _buildMetaInfoDivider(),
                            StreamBuilder<QuerySnapshot>(
                              stream: teacherId.trim().isNotEmpty
                                  ? FirebaseFirestore.instance
                                      .collection('follow_requests')
                                      .where('teacherId', isEqualTo: teacherId)
                                      .where('status', isEqualTo: 'accepted')
                                      .snapshots()
                                  : const Stream.empty(),
                              builder: (context, sSnap) {
                                final int safeFallbackStudents =
                                    studentCount < 0 ? 0 : studentCount;
                                final int displayStudents = sSnap.hasData
                                    ? sSnap.data!.docs.length
                                    : safeFallbackStudents;
                                return _buildMetaInfoItem(
                                  Icons.school_rounded,
                                  "$displayStudents",
                                  "Students",
                                  iconColor: _brandBlue,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Bottom Action Buttons (View Profile + Chat Now)
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _brandBlue,
                                  side: const BorderSide(
                                    color: Color(0xFFCBD5E1),
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  onProfilePressed?.call();
                                },
                                icon: const Icon(
                                  Icons.person_search_rounded,
                                  size: 17,
                                  color: _brandBlue,
                                ),
                                label: const Text(
                                  "View Profile",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _primaryNavy,
                                    fontSize: 13.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0F766E),
                                    Color(0xFF0D9488)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accentTeal.withOpacity(0.26),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  onChatPressed();
                                },
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "Chat Now",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetaInfoItem(
    IconData icon,
    String value,
    String label, {
    required Color iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 13.5, color: iconColor),
            ),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: _primaryNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildMetaInfoDivider() {
    return Container(
      height: 24,
      width: 1,
      color: const Color(0xFFE2E8F0),
    );
  }
}
