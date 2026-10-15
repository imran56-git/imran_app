import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/connected_user_model.dart';

class ConnectionActionBottomSheet extends StatelessWidget {
  final ConnectedUserModel user;
  final VoidCallback onMessage;
  final VoidCallback onUnfollowConfirm;

  const ConnectionActionBottomSheet({
    Key? key,
    required this.user,
    required this.onMessage,
    required this.onUnfollowConfirm,
  }) : super(key: key);

  static const Color _primaryNavy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _dangerRed = Color(0xFFDC2626);

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

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  void _showUnfollowDialog(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Unfollow Dialog',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, anim, __, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(
              opacity: anim,
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
                contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_remove_alt_1_rounded,
                        color: _dangerRed,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Unfollow ${user.name}?",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: _primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  "You will no longer have this active connection with ${user.name}. You can always send a new request later.",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _dangerRed,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            Navigator.pop(dialogContext);
                            onUnfollowConfirm();
                          },
                          child: const Text(
                            "Unfollow",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String photoUrl = _resolvePhotoUrl();
    final bool hasPhoto = photoUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            Container(
              width: 44,
              height: 4.5,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // User Identity Summary Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_brandBlue, _accentBlue],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: _brandBlue,
                      backgroundImage:
                          hasPhoto ? NetworkImage(photoUrl) : null,
                      child: !hasPhoto
                          ? Text(
                              _getInitials(user.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name.isNotEmpty ? user.name : 'Connected User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isTeacherRole
                              ? 'Connected Educator'
                              : 'Connected Student',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Option 1: Direct Message
            _buildActionOptionTile(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: _accentBlue,
              iconBg: const Color(0xFFEFF6FF),
              title: "Message",
              subtitle: "Open direct private conversation",
              titleColor: _primaryNavy,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                onMessage();
              },
            ),
            const SizedBox(height: 10),

            // Option 2: Unfollow / Remove
            _buildActionOptionTile(
              icon: Icons.person_remove_outlined,
              iconColor: _dangerRed,
              iconBg: const Color(0xFFFEE2E2),
              title: "Unfollow",
              subtitle: "Remove from your active network",
              titleColor: _dangerRed,
              borderColor: const Color(0xFFFECACA),
              onTap: () => _showUnfollowDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionOptionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required Color titleColor,
    required VoidCallback onTap,
    Color borderColor = const Color(0xFFE2E8F0),
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: titleColor.withOpacity(0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
