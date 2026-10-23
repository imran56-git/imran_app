import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum BadgeType {
  verified,
  golden,
  masterOfSubject,
  bestOfSubject,
  kingOfSubject,
  verifiedBatch,
}

class BadgeTierResolver {
  static bool isTeacherVerified(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data['isVerified'] == true ||
        data['verified'] == true ||
        data['status']?.toString().toLowerCase() == 'approved' ||
        data['verificationStatus']?.toString().toLowerCase() == 'verified';
  }

  static bool hasGoldenTenureBadge(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['hasGoldenBadge'] == true || data['goldenBadge'] == true) {
      return true;
    }
    final dynamic createdAt = data['createdAt'] ?? data['joinedAt'];
    if (createdAt != null) {
      DateTime? joinDate;
      if (createdAt is DateTime) {
        joinDate = createdAt;
      } else {
        try {
          joinDate = (createdAt as dynamic).toDate() as DateTime?;
        } catch (_) {}
      }
      if (joinDate != null) {
        final int daysOnPlatform = DateTime.now().difference(joinDate).inDays;
        if (daysOnPlatform >= 1095) {
          return true;
        }
      }
    }
    return false;
  }

  static BadgeType? resolveAcademicQualityBadge(Map<String, dynamic>? data) {
    if (data == null) return null;

    final String rawBadge = (data['academicBadge'] ??
            data['qualityBadge'] ??
            data['tierBadge'] ??
            data['subjectBadge'] ??
            data['rankBadge'] ??
            data['badge'] ??
            '')
        .toString()
        .trim()
        .toUpperCase();

    if (rawBadge == 'K' ||
        rawBadge.contains('KING') ||
        data['isKingOfSubject'] == true ||
        data['hasKBadge'] == true) {
      return BadgeType.kingOfSubject;
    }
    if (rawBadge == 'M' ||
        rawBadge.contains('MASTER') ||
        data['isMasterOfSubject'] == true ||
        data['hasMBadge'] == true) {
      return BadgeType.masterOfSubject;
    }
    if (rawBadge == 'B' ||
        rawBadge.contains('BEST') ||
        data['isBestOfSubject'] == true ||
        data['hasBBadge'] == true) {
      return BadgeType.bestOfSubject;
    }

    final double avgRating =
        (data['averageRating'] ?? data['allTimeRating'] ?? 0.0) is num
            ? ((data['averageRating'] ?? data['allTimeRating'] ?? 0.0) as num)
                .toDouble()
            : 0.0;

    if (avgRating >= 5.0) {
      return BadgeType.kingOfSubject;
    } else if (avgRating >= 4.2) {
      return BadgeType.bestOfSubject;
    } else if (avgRating >= 3.8) {
      return BadgeType.masterOfSubject;
    }

    return null;
  }
}

class BottomToTopShimmer extends StatefulWidget {
  final Widget child;
  final Color shimmerColor;
  final Duration duration;

  const BottomToTopShimmer({
    super.key,
    required this.child,
    this.shimmerColor = Colors.white,
    this.duration = const Duration(milliseconds: 2600),
  });

  @override
  State<BottomToTopShimmer> createState() => _BottomToTopShimmerState();
}

class _BottomToTopShimmerState extends State<BottomToTopShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double progress = _controller.value;
        final double slide = 1.6 - (progress * 3.2);

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment(-0.2, slide + 0.55),
              end: Alignment(0.2, slide - 0.55),
              colors: [
                Colors.transparent,
                widget.shimmerColor.withOpacity(0.12),
                widget.shimmerColor.withOpacity(0.68),
                widget.shimmerColor.withOpacity(0.12),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class FullscreenBadgeViewer extends StatelessWidget {
  final BadgeType badgeType;
  final String title;
  final String tag;

  const FullscreenBadgeViewer({
    super.key,
    required this.badgeType,
    required this.title,
    required this.tag,
  });

  static void show(
    BuildContext context, {
    required BadgeType badgeType,
    required String title,
    required String tag,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullscreenBadgeViewer(
            badgeType: badgeType,
            title: title,
            tag: tag,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.black.withOpacity(0.92),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, right: 14),
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: InteractiveViewer(
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(40),
                      minScale: 0.8,
                      maxScale: 3.5,
                      child: Hero(
                        tag: 'fullscreen_badge_${badgeType.name}',
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.65),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: InteractiveBadgeIcon._buildRawBadgeGraphic(
                            badgeType,
                            240,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.24),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pinch to zoom • Tap anywhere to close',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InteractiveBadgeIcon extends StatelessWidget {
  final BadgeType badgeType;
  final String holderName;
  final String? subjectName;
  final double size;
  final bool showLabelPill;

  const InteractiveBadgeIcon({
    super.key,
    required this.badgeType,
    required this.holderName,
    this.subjectName,
    this.size = 20,
    this.showLabelPill = false,
  });

  void _handleTap(BuildContext context) {
    HapticFeedback.selectionClick();
    BadgeDetailsSheet.show(
      context,
      badgeType: badgeType,
      holderName: holderName,
      subjectName: subjectName,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showLabelPill && badgeType == BadgeType.verified) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleTap(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF7DD3FC), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BottomToTopShimmer(
                child: Icon(
                  Icons.verified_rounded,
                  color: const Color(0xFF0284C7),
                  size: size * 0.82,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Verified',
                style: TextStyle(
                  color: Color(0xFF0369A1),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: BottomToTopShimmer(
          child: _buildRawBadgeGraphic(badgeType, size),
        ),
      ),
    );
  }

  static Widget _buildRawBadgeGraphic(BadgeType type, double size) {
    String? assetPath;
    switch (type) {
      case BadgeType.verified:
      case BadgeType.verifiedBatch:
        assetPath = 'assets/images/Verified_Batch.png';
        break;
      case BadgeType.golden:
        assetPath = 'assets/images/Golden_Batch.png';
        break;
      case BadgeType.kingOfSubject:
        assetPath = 'assets/images/k_badge.png';
        break;
      case BadgeType.masterOfSubject:
        assetPath = 'assets/images/m_badge.png';
        break;
      case BadgeType.bestOfSubject:
        assetPath = 'assets/images/b_badge.png';
        break;
    }

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        Icons.workspace_premium_rounded,
        color: const Color(0xFFD97706),
        size: size,
      ),
    );
  }
}

class TeacherBadgesRow extends StatelessWidget {
  final String teacherName;
  final bool isVerified;
  final bool hasGoldenBadge;
  final BadgeType? qualityBadge;
  final String? subjectName;
  final double badgeSize;
  final bool showVerifiedTextWhenSingle;

  const TeacherBadgesRow({
    super.key,
    required this.teacherName,
    required this.isVerified,
    this.hasGoldenBadge = false,
    this.qualityBadge,
    this.subjectName,
    this.badgeSize = 20,
    this.showVerifiedTextWhenSingle = false,
  });

  factory TeacherBadgesRow.fromMap({
    Key? key,
    required Map<String, dynamic>? teacherData,
    required String fallbackName,
    double badgeSize = 20,
    bool showVerifiedTextWhenSingle = false,
  }) {
    final String name = (teacherData?['name'] ??
            teacherData?['fullName'] ??
            fallbackName)
        .toString()
        .trim();
    final List<dynamic> subjects =
        (teacherData?['subjects'] as List<dynamic>?) ?? const [];
    final String? primarySubject =
        subjects.isNotEmpty ? subjects.first.toString() : null;

    return TeacherBadgesRow(
      key: key,
      teacherName: name.isEmpty ? 'Educator' : name,
      isVerified: BadgeTierResolver.isTeacherVerified(teacherData),
      hasGoldenBadge: BadgeTierResolver.hasGoldenTenureBadge(teacherData),
      qualityBadge: BadgeTierResolver.resolveAcademicQualityBadge(teacherData),
      subjectName: primarySubject,
      badgeSize: badgeSize,
      showVerifiedTextWhenSingle: showVerifiedTextWhenSingle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalBadges = (isVerified ? 1 : 0) +
        (hasGoldenBadge ? 1 : 0) +
        (qualityBadge != null ? 1 : 0);

    if (totalBadges == 0) {
      return const SizedBox.shrink();
    }

    final bool showPill =
        showVerifiedTextWhenSingle && totalBadges == 1 && isVerified;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isVerified)
          InteractiveBadgeIcon(
            badgeType: BadgeType.verified,
            holderName: teacherName,
            subjectName: subjectName,
            size: badgeSize,
            showLabelPill: showPill,
          ),
        if (hasGoldenBadge) ...[
          const SizedBox(width: 4),
          InteractiveBadgeIcon(
            badgeType: BadgeType.golden,
            holderName: teacherName,
            subjectName: subjectName,
            size: badgeSize,
          ),
        ],
        if (qualityBadge != null) ...[
          const SizedBox(width: 4),
          InteractiveBadgeIcon(
            badgeType: qualityBadge!,
            holderName: teacherName,
            subjectName: subjectName,
            size: badgeSize,
          ),
        ],
      ],
    );
  }
}

class AvatarCornerBadge extends StatelessWidget {
  final BadgeType badgeType;
  final String holderName;
  final double size;

  const AvatarCornerBadge({
    super.key,
    required this.badgeType,
    required this.holderName,
    this.size = 18,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        BadgeDetailsSheet.show(
          context,
          badgeType: badgeType,
          holderName: holderName,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: BottomToTopShimmer(
          child: InteractiveBadgeIcon._buildRawBadgeGraphic(badgeType, size),
        ),
      ),
    );
  }
}

class BadgeDetailsSheet extends StatelessWidget {
  final BadgeType badgeType;
  final String holderName;
  final String? subjectName;

  const BadgeDetailsSheet({
    super.key,
    required this.badgeType,
    required this.holderName,
    this.subjectName,
  });

  static Future<void> show(
    BuildContext context, {
    required BadgeType badgeType,
    required String holderName,
    String? subjectName,
  }) {
    final String cleanName =
        holderName.trim().isEmpty ? 'This Group' : holderName.trim();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF0F172A).withOpacity(0.55),
      builder: (_) => BadgeDetailsSheet(
        badgeType: badgeType,
        holderName: cleanName,
        subjectName: subjectName,
      ),
    );
  }

  _BadgeSpec _resolveSpec() {
    final String subjectLabel =
        (subjectName != null && subjectName!.trim().isNotEmpty)
            ? subjectName!.trim()
            : 'Core Academic Subjects';

    switch (badgeType) {
      case BadgeType.verified:
        return _BadgeSpec(
          tag: 'OFFICIAL CREDENTIAL',
          title: 'Verified Educator',
          subtitle:
              'Awarded to $holderName for completing identity authentication, academic profile verification, and platform trust standards.',
          primaryColor: const Color(0xFF0284C7),
          secondaryColor: const Color(0xFF1E3A8A),
          lightBg: const Color(0xFFF0F9FF),
          borderTint: const Color(0xFFBAE6FD),
          pillars: [
            _BadgePillar(
              icon: Icons.verified_user_rounded,
              title: 'Authenticated Educator Identity',
              description:
                  '$holderName\'s academic credentials, contact authenticity, and teaching profile have been verified by FYBTT.',
            ),
            _BadgePillar(
              icon: Icons.school_rounded,
              title: 'Trusted Learning Environment',
              description:
                  'Maintains transparent batch communication, verified student connections, and ethical educational standards.',
            ),
            _BadgePillar(
              icon: Icons.shield_rounded,
              title: 'Continuous Quality Compliance',
              description:
                  'Actively upholds platform safety guidelines and consistent responsiveness for enrolled students.',
            ),
          ],
        );

      case BadgeType.golden:
        return _BadgeSpec(
          tag: '3+ YEARS TENURE MILESTONE',
          title: 'Golden Legacy Educator',
          subtitle:
              'Conferred upon $holderName in recognition of completing 3+ consecutive years of dedicated mentorship on FYBTT.',
          primaryColor: const Color(0xFFD97706),
          secondaryColor: const Color(0xFF78350F),
          lightBg: const Color(0xFFFFFBEB),
          borderTint: const Color(0xFFFDE68A),
          pillars: [
            _BadgePillar(
              icon: Icons.workspace_premium_rounded,
              title: 'Three-Year Academic Legacy',
              description:
                  '$holderName has successfully guided students across multiple academic seasons for over three years.',
            ),
            _BadgePillar(
              icon: Icons.auto_graph_rounded,
              title: 'Sustained Mentorship Consistency',
              description:
                  'Demonstrates long-term reliability, batch stability, and enduring trust within the student community.',
            ),
            _BadgePillar(
              icon: Icons.military_tech_rounded,
              title: 'Senior Educator Standing',
              description:
                  'Recognized among our most seasoned educators with an established track record of academic service.',
            ),
          ],
        );

      case BadgeType.kingOfSubject:
        return _BadgeSpec(
          tag: 'TIER-1 ACADEMIC DISTINCTION • K BADGE',
          title: 'King of the Subject',
          subtitle:
              'Our highest academic honor awarded to $holderName for achieving a perfect 5.0-star rating and absolute mastery in $subjectLabel.',
          primaryColor: const Color(0xFF6D28D9),
          secondaryColor: const Color(0xFF3B0764),
          lightBg: const Color(0xFFF5F3FF),
          borderTint: const Color(0xFFDDD6FE),
          pillars: [
            _BadgePillar(
              icon: Icons.emoji_events_rounded,
              title: 'Unrivaled 5.0 Mastery',
              description:
                  '$holderName maintains a flawless 5.0-star rating, standing at the pinnacle of conceptual clarity and subject command.',
            ),
            _BadgePillar(
              icon: Icons.stars_rounded,
              title: 'Elite Student Endorsements',
              description:
                  'Earned through exceptional seasonal reviews and top-tier student satisfaction scores.',
            ),
            _BadgePillar(
              icon: Icons.psychology_rounded,
              title: 'Transformative Mentorship',
              description:
                  'Celebrated for imparting deep subject insights, exceptional punctuality, and inspiring academic outcomes.',
            ),
          ],
        );

      case BadgeType.bestOfSubject:
        return _BadgeSpec(
          tag: 'ADVANCED PEDAGOGY • B BADGE',
          title: 'Best of the Subject',
          subtitle:
              'Awarded to $holderName for maintaining a stellar minimum 4.2-star rating, demonstrating superior teaching excellence in $subjectLabel.',
          primaryColor: const Color(0xFF0D9488),
          secondaryColor: const Color(0xFF115E59),
          lightBg: const Color(0xFFF0FDFA),
          borderTint: const Color(0xFF99F6E4),
          pillars: [
            _BadgePillar(
              icon: Icons.menu_book_rounded,
              title: 'Superior Teaching Excellence',
              description:
                  '$holderName consistently delivers structured, engaging instruction backed by strong seasonal feedback.',
            ),
            _BadgePillar(
              icon: Icons.forum_rounded,
              title: 'Effective Doubt Resolution',
              description:
                  'Highly praised by students for clear communication, interactive classes, and approachable guidance.',
            ),
            _BadgePillar(
              icon: Icons.trending_up_rounded,
              title: 'Consistent 4.2+ Rating',
              description:
                  'Maintains high performance benchmarks across teaching quality, knowledge, and discipline.',
            ),
          ],
        );

      case BadgeType.masterOfSubject:
        return _BadgeSpec(
          tag: 'RECOGNIZED QUALITY • M BADGE',
          title: 'Master of the Subject',
          subtitle:
              'Presented to $holderName for maintaining a solid minimum 3.8-star rating over the past 3 months in $subjectLabel.',
          primaryColor: const Color(0xFF2563EB),
          secondaryColor: const Color(0xFF1E3A8A),
          lightBg: const Color(0xFFEFF6FF),
          borderTint: const Color(0xFFBFDBFE),
          pillars: [
            _BadgePillar(
              icon: Icons.thumb_up_alt_rounded,
              title: 'Reliable Student Evaluations',
              description:
                  '$holderName has successfully maintained positive seasonal ratings and steady classroom engagement.',
            ),
            _BadgePillar(
              icon: Icons.schedule_rounded,
              title: 'Dedicated Classroom Commitment',
              description:
                  'Recognized for regular class conduct, organized study materials, and supportive student mentorship.',
            ),
            _BadgePillar(
              icon: Icons.verified_outlined,
              title: 'Verified 3-Month Benchmark',
              description:
                  'Meets FYBTT\'s active seasonal criteria for consistent teaching reliability and student satisfaction.',
            ),
          ],
        );

      case BadgeType.verifiedBatch:
        return _BadgeSpec(
          tag: 'OFFICIAL ACADEMIC BATCH',
          title: 'Verified Study Batch',
          subtitle:
              '"$holderName" is an official, educator-moderated academic group operated by a Verified Teacher on FYBTT.',
          primaryColor: const Color(0xFF0284C7),
          secondaryColor: const Color(0xFF0F172A),
          lightBg: const Color(0xFFF0F9FF),
          borderTint: const Color(0xFFBAE6FD),
          pillars: [
            _BadgePillar(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Verified Educator Administration',
              description:
                  'Directly managed by an authenticated teacher ensuring accurate notices, homework, and study materials.',
            ),
            _BadgePillar(
              icon: Icons.lock_person_rounded,
              title: 'Protected Student Privacy',
              description:
                  'Enforces strict member privacy where student identities and contact details remain fully safeguarded.',
            ),
            _BadgePillar(
              icon: Icons.library_books_rounded,
              title: 'Structured Academic Curriculum',
              description:
                  'Verified for organized batch schedules, assessments, and distraction-free academic collaboration.',
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final _BadgeSpec spec = _resolveSpec();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              spec.secondaryColor,
                              spec.primaryColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: spec.primaryColor.withOpacity(0.26),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                FullscreenBadgeViewer.show(
                                  context,
                                  badgeType: badgeType,
                                  title: spec.title,
                                  tag: spec.tag,
                                );
                              },
                              child: Hero(
                                tag: 'fullscreen_badge_${badgeType.name}',
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.35),
                                      width: 1.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.18),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: BottomToTopShimmer(
                                    duration:
                                        const Duration(milliseconds: 2200),
                                    child: InteractiveBadgeIcon
                                        ._buildRawBadgeGraphic(
                                      badgeType,
                                      96,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                spec.tag,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              spec.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              spec.subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 13,
                                height: 1.42,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          badgeType == BadgeType.verifiedBatch
                              ? 'WHY ${holderName.toUpperCase()} IS A VERIFIED BATCH'
                              : 'WHY ${holderName.toUpperCase()} HOLDS THIS DISTINCTION',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...spec.pillars.map(
                        (pillar) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: spec.lightBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: spec.borderTint),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(13),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          spec.primaryColor.withOpacity(0.10),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  pillar.icon,
                                  color: spec.primaryColor,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pillar.title,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 14.2,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      pillar.description,
                                      style: const TextStyle(
                                        color: Color(0xFF475569),
                                        fontSize: 12.6,
                                        height: 1.38,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Got It',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeSpec {
  final String tag;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final Color secondaryColor;
  final Color lightBg;
  final Color borderTint;
  final List<_BadgePillar> pillars;

  const _BadgeSpec({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.secondaryColor,
    required this.lightBg,
    required this.borderTint,
    required this.pillars,
  });
}

class _BadgePillar {
  final IconData icon;
  final String title;
  final String description;

  const _BadgePillar({
    required this.icon,
    required this.title,
    required this.description,
  });
}
