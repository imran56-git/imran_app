import 'package:flutter/material.dart';

enum BadgeStyle { compact, full, iconOnly }

class TeacherBadgeWidget extends StatelessWidget {
  final String badgeType; // 'master', 'golden', 'verified'
  final BadgeStyle style;
  final double iconSize;

  const TeacherBadgeWidget({
    super.key,
    required this.badgeType,
    this.style = BadgeStyle.full,
    this.iconSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final badgeConfig = _getBadgeConfig(badgeType.toLowerCase());

    if (badgeConfig == null) {
      return const SizedBox.shrink(); // No badge to show
    }

    if (style == BadgeStyle.iconOnly) {
      return Tooltip(
        message: badgeConfig.title,
        child: Icon(
          badgeConfig.icon,
          size: iconSize,
          color: badgeConfig.primaryColor,
        ),
      );
    }

    if (style == BadgeStyle.compact) {
      return Tooltip(
        message: badgeConfig.title,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: badgeConfig.primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: badgeConfig.primaryColor.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                badgeConfig.icon,
                size: iconSize,
                color: badgeConfig.primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                badgeConfig.shortTitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: badgeConfig.primaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Full style with gradient background
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: badgeConfig.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: badgeConfig.primaryColor.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeConfig.icon,
            size: iconSize,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            badgeConfig.title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig? _getBadgeConfig(String type) {
    switch (type) {
      case 'master':
        return _BadgeConfig(
          title: 'Master Teacher',
          shortTitle: 'Master',
          icon: Icons.workspace_premium_rounded,
          primaryColor: const Color(0xFF7C4DFF),
          gradientColors: const [Color(0xFF7C4DFF), Color(0xFF536DFE)],
        );
      case 'golden':
        return _BadgeConfig(
          title: 'Gold Star',
          shortTitle: 'Gold',
          icon: Icons.stars_rounded,
          primaryColor: const Color(0xFFFFAB00),
          gradientColors: const [Color(0xFFFFC107), Color(0xFFFF8F00)],
        );
      case 'verified':
        return _BadgeConfig(
          title: 'Verified',
          shortTitle: 'Verified',
          icon: Icons.verified_rounded,
          primaryColor: const Color(0xFF0288D1),
          gradientColors: const [Color(0xFF29B6F6), Color(0xFF0288D1)],
        );
      default:
        return null;
    }
  }
}

class _BadgeConfig {
  final String title;
  final String shortTitle;
  final IconData icon;
  final Color primaryColor;
  final List<Color> gradientColors;

  _BadgeConfig({
    required this.title,
    required this.shortTitle,
    required this.icon,
    required this.primaryColor,
    required this.gradientColors,
  });
}