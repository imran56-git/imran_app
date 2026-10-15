import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/connected_user_model.dart';

class ConnectedUserTile extends StatelessWidget {
  final ConnectedUserModel user;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const ConnectedUserTile({
    Key? key,
    required this.user,
    required this.onTap,
    required this.onMoreTap,
  }) : super(key: key);

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentTeal = Color(0xFF0F766E);

  bool get _isTeacherRole => user.role.toLowerCase().contains('teacher');

  String _resolvePhotoUrl() {
    if (user.photoUrl != null && user.photoUrl!.trim().isNotEmpty) {
      return user.photoUrl!.trim();
    }
    if (user.profileImageUrl != null &&
        user.profileImageUrl!.trim().isNotEmpty) {
      return user.profileImageUrl!.trim();
    }
    return '';
  }

  String _getDisplaySubtitle() {
    final tuition = user.tuitionName?.trim();
    if (tuition != null &&
        tuition.isNotEmpty &&
        tuition.toLowerCase() != 'null' &&
        tuition.toLowerCase() != 'not set') {
      return "From $tuition";
    }

    final sub = user.subtitle?.trim();
    if (sub != null &&
        sub.isNotEmpty &&
        sub.toLowerCase() != 'null' &&
        sub.toLowerCase() != 'not set') {
      return sub.toLowerCase().startsWith('from ') ? sub : "From $sub";
    }

    return _isTeacherRole ? "Connected Educator" : "Connected Student";
  }

  List<Color> _getAvatarGradient(String text) {
    final gradients = <List<Color>>[
      [const Color(0xFF1E4C7A), const Color(0xFF2563EB)],
      [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
      [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
      [const Color(0xFF0369A1), const Color(0xFF0284C7)],
    ];
    if (text.isEmpty) return gradients.first;
    return gradients[text.codeUnitAt(0) % gradients.length];
  }

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildInitialAvatar(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(user.name),
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayPhoto = _resolvePhotoUrl();
    final bool hasPhoto = displayPhoto.isNotEmpty;
    final avatarColors = _getAvatarGradient(user.name);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: _primaryNavy.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          splashColor: _brandBlue.withOpacity(0.04),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar with Gradient Ring & Role Badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: avatarColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: ClipOval(
                            child: hasPhoto
                                ? Image.network(
                                    displayPhoto,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildInitialAvatar(avatarColors),
                                  )
                                : _buildInitialAvatar(avatarColors),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: _isTeacherRole
                              ? _brandBlue
                              : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.8),
                        ),
                        child: Icon(
                          _isTeacherRole
                              ? Icons.school_rounded
                              : Icons.check_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // User Name, Connected Badge & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.name.isNotEmpty ? user.name : 'User',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.8,
                                fontWeight: FontWeight.w800,
                                color: _primaryNavy,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: const Text(
                              'Connected',
                              style: TextStyle(
                                fontSize: 9.8,
                                fontWeight: FontWeight.w800,
                                color: _accentTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              _isTeacherRole
                                  ? Icons.domain_rounded
                                  : Icons.school_outlined,
                              size: 12.5,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _getDisplaySubtitle(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Styled More Options Button
                Material(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onMoreTap();
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.more_horiz_rounded,
                        color: Color(0xFF475569),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
