import 'package:flutter/material.dart';
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

    return "Connected Student";
  }

  Widget _buildInitialAvatar() {
    final initial = user.name.trim().isNotEmpty
        ? user.name.trim()[0].toUpperCase()
        : 'U';

    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = user.photoUrl != null && user.photoUrl!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: ClipOval(
                    child: hasPhoto
                        ? Image.network(
                            user.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildInitialAvatar(),
                          )
                        : _buildInitialAvatar(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.school_outlined,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _getDisplaySubtitle(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
                  onPressed: onMoreTap,
                  splashRadius: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
