import 'package:flutter/material.dart';
import 'teacher_badge_widget.dart';

class LeaderboardCardWidget extends StatelessWidget {
  final int rank;
  final String teacherName;
  final String? profileImageUrl;
  final String badgeType; // 'master', 'golden', 'verified'
  final double rating;
  final int reviewCount;
  final VoidCallback? onTap;

  const LeaderboardCardWidget({
    super.key,
    required this.rank,
    required this.teacherName,
    this.profileImageUrl,
    required this.badgeType,
    required this.rating,
    required this.reviewCount,
    this.onTap,
  });

  Color _getRankColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFF64748B); // Standard Grey
    }
  }

  Widget _buildRankBadge() {
    final color = _getRankColor();
    final isTopThree = rank <= 3;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isTopThree ? color.withOpacity(0.15) : const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(
          color: isTopThree ? color : Colors.transparent,
          width: isTopThree ? 2 : 0,
        ),
      ),
      child: Center(
        child: isTopThree
            ? Icon(
                Icons.emoji_events_rounded,
                color: color,
                size: 20,
              )
            : Text(
                '#$rank',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF334155),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1E4C7A);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Rank Badge (#1, #2, #3 or #Rank Number)
                _buildRankBadge(),
                const SizedBox(width: 12),

                // Profile Image
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                      ? NetworkImage(profileImageUrl!)
                      : null,
                  child: (profileImageUrl == null || profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person_rounded, size: 28, color: primaryColor)
                      : null,
                ),
                const SizedBox(width: 12),

                // Teacher Info & Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              teacherName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          TeacherBadgeWidget(
                            badgeType: badgeType,
                            style: BadgeStyle.iconOnly,
                            iconSize: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFFFB300),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '($reviewCount reviews)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Dynamic Badge Label
                TeacherBadgeWidget(
                  badgeType: badgeType,
                  style: BadgeStyle.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
