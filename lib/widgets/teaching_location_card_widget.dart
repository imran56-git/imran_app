import 'package:flutter/material.dart';
import '../models/teacher_location_model.dart';
import '../models/teaching_batch_model.dart';
import '../services/teacher_location_service.dart';

class TeachingLocationCardWidget extends StatelessWidget {
  final TeacherLocationModel location;
  final bool isOwner;
  final double? studentDistanceKm;
  final int? estimatedTravelMinutes;
  final VoidCallback? onViewOnMap;
  final VoidCallback? onViewSchedule;
  final VoidCallback? onGetDirections;
  final VoidCallback? onEditLocation;
  final VoidCallback? onManageBatches;

  const TeachingLocationCardWidget({
    super.key,
    required this.location,
    this.isOwner = false,
    this.studentDistanceKm,
    this.estimatedTravelMinutes,
    this.onViewOnMap,
    this.onViewSchedule,
    this.onGetDirections,
    this.onEditLocation,
    this.onManageBatches,
  });

  // Executive Palette Constants FYBTT 2.0
  static const Color _navy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _emerald = Color(0xFF059669);
  static const Color _amber = Color(0xFFD97706);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _mutedSlate = Color(0xFF64748B);
  static const Color _surfaceSlate = Color(0xFFF8FAFC);

  String get _resolvedAddress {
    final String full = location.fullAddress;
    if (full.trim().isNotEmpty) return full;
    try {
      final dynamic dynamicLoc = location;
      final dynamic addr = dynamicLoc.address;
      if (addr != null && addr.toString().trim().isNotEmpty) {
        return addr.toString();
      }
    } catch (_) {}
    return full;
  }

  String _formatLocationType(String type) {
    switch (type.toLowerCase()) {
      case 'tuition_centre':
        return 'Tuition Centre';
      case 'institute':
        return 'Institute / Coaching';
      case 'home_tuition':
        return 'Home Tuition Base';
      case 'school':
        return 'School Campus';
      case 'other':
        return 'Independent Centre';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  IconData _getLocationTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'tuition_centre':
        return Icons.business_outlined;
      case 'institute':
        return Icons.account_balance_outlined;
      case 'home_tuition':
        return Icons.home_work_outlined;
      case 'school':
        return Icons.school_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  String _formatTeachingMode(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'offline':
        return 'Offline Classroom';
      case 'hybrid':
        return 'Hybrid Centre';
      case 'online':
        return 'Online Only';
      default:
        return 'Offline Teaching';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = location.isActive != false;
    final bool isVerified = location.verificationStatus == 'verified';

    return Opacity(
      opacity: isActive ? 1.0 : 0.88,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? _cardBorder : Colors.red.shade100,
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              offset: Offset(0, 4),
              blurRadius: 16,
              spreadRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isActive) _buildInactiveNotice(),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(context, isVerified),
                  const SizedBox(height: 12),
                  _buildTitleAndAddress(),
                  const SizedBox(height: 12),
                  _buildBatchAndSchedulePreview(),
                  if ((location.subjects?.isNotEmpty ?? false) ||
                      (location.classes?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 12),
                    _buildTagsSection(),
                  ],
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: _cardBorder),
                  const SizedBox(height: 12),
                  _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFEF2F2),
      child: Row(
        children: [
          Icon(Icons.pause_circle_outline, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Centre Temporarily Inactive (Hidden from Public Search)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, bool isVerified) {
    return Row(
      children: [
        // Type Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          decoration: BoxDecoration(
            color: _brandBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _brandBlue.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getLocationTypeIcon(location.locationType), size: 14, color: _brandBlue),
              const SizedBox(width: 6),
              Text(
                _formatLocationType(location.locationType),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _brandBlue,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
        if (isVerified) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 13, color: _emerald),
                SizedBox(width: 4),
                Text(
                  'Verified',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _emerald,
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        // Right Side: Owner menu or Student Distance Pill
        if (isOwner)
          _buildOwnerDropdownMenu(context)
        else if (studentDistanceKm != null)
          _buildDistanceBadge(),
      ],
    );
  }

  Widget _buildDistanceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: _surfaceSlate,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me_outlined, size: 13, color: _accentBlue),
          const SizedBox(width: 4),
          Text(
            estimatedTravelMinutes != null
                ? '${studentDistanceKm!.toStringAsFixed(1)} KM • $estimatedTravelMinutes mins'
                : '${studentDistanceKm!.toStringAsFixed(1)} KM away',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerDropdownMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: _mutedSlate),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        if (val == 'edit' && onEditLocation != null) {
          onEditLocation!();
        } else if (val == 'batches' && onManageBatches != null) {
          onManageBatches!();
        } else if (val == 'map' && onViewOnMap != null) {
          onViewOnMap!();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: _navy),
              SizedBox(width: 10),
              Text('Edit Centre Details', style: TextStyle(fontSize: 13, color: _navy)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'batches',
          child: Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 18, color: _navy),
              SizedBox(width: 10),
              Text('Manage Batches & Timetable', style: TextStyle(fontSize: 13, color: _navy)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'map',
          child: Row(
            children: [
              Icon(Icons.map_outlined, size: 18, color: _navy),
              SizedBox(width: 10),
              Text('View on Map', style: TextStyle(fontSize: 13, color: _navy)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitleAndAddress() {
    final String addressText = _resolvedAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                location.locationName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                  letterSpacing: -0.3,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _surfaceSlate,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _cardBorder),
              ),
              child: Text(
                _formatTeachingMode(location.teachingMode),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: _mutedSlate,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.location_on, size: 15, color: Color(0xFFEF4444)),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                addressText.isNotEmpty ? addressText : 'Address details unavailable',
                style: const TextStyle(
                  fontSize: 13,
                  color: _mutedSlate,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBatchAndSchedulePreview() {
    return StreamBuilder<List<TeachingBatchModel>>(
      stream: TeacherLocationService().getBatchesStream(
        location.teacherId,
        location.id,
      ),
      builder: (context, snapshot) {
        final batches = snapshot.data ?? [];

        if (batches.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceSlate,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cardBorder.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: _mutedSlate),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isOwner
                        ? 'No active batches configured yet. Tap "Manage" to set timings.'
                        : 'Contact educator directly for custom batch availability.',
                    style: const TextStyle(fontSize: 11.5, color: _mutedSlate),
                  ),
                ),
              ],
            ),
          );
        }

        final activeBatches = batches.where((b) => b.isActive).toList();
        final int activeBatchCount = activeBatches.length;

        final subjects = activeBatches
            .map((b) => b.subject)
            .where((s) => s.trim().isNotEmpty)
            .toSet();

        final classLevels = activeBatches
            .map((b) => b.classLevel)
            .where((c) => c.trim().isNotEmpty)
            .toSet();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _surfaceSlate,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            children: [
              // Batches Count
              _buildMetricChip(
                icon: Icons.groups_outlined,
                text: '$activeBatchCount Active ${activeBatchCount == 1 ? 'Batch' : 'Batches'}',
                color: _brandBlue,
              ),
              if (subjects.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricChip(
                    icon: Icons.menu_book_outlined,
                    text: subjects.take(2).join(', '),
                    color: _navy,
                  ),
                ),
              ],
              if (classLevels.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildMetricChip(
                  icon: Icons.school_outlined,
                  text: classLevels.first,
                  color: _amber,
                ),
              ] else if (activeBatches.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildMetricChip(
                  icon: Icons.event_seat_outlined,
                  text: activeBatches.first.seatStatusDisplay,
                  color: _emerald,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color == _navy ? _navy : color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    final subjects = location.subjects ?? [];
    final classes = location.classes ?? [];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...subjects.take(3).map((sub) => _buildPillTag(
              label: sub,
              bgColor: _accentBlue.withValues(alpha: 0.08),
              textColor: _accentBlue,
            )),
        if (subjects.length > 3)
          _buildPillTag(
            label: '+${subjects.length - 3} more',
            bgColor: _surfaceSlate,
            textColor: _mutedSlate,
          ),
        ...classes.take(2).map((cls) => _buildPillTag(
              label: cls,
              bgColor: _surfaceSlate,
              textColor: _navy,
              borderColor: _cardBorder,
            )),
      ],
    );
  }

  Widget _buildPillTag({
    required String label,
    required Color bgColor,
    required Color textColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor ?? Colors.transparent),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (isOwner) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: onManageBatches,
              icon: const Icon(Icons.date_range, size: 16),
              label: const Text('Manage Batches'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: onEditLocation,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _cardBorder, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              child: const Text('Edit', style: TextStyle(color: _navy)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onViewOnMap,
            icon: const Icon(Icons.map_outlined, size: 19, color: _mutedSlate),
            tooltip: 'View on Map',
            splashRadius: 20,
          ),
        ],
      );
    }

    return Row(
      children: [
        // Primary: Get Directions
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: onGetDirections,
            icon: const Icon(Icons.directions, size: 16),
            label: const Text('Directions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Secondary: View Schedule
        Expanded(
          flex: 3,
          child: OutlinedButton.icon(
            onPressed: onViewSchedule,
            icon: const Icon(Icons.calendar_today, size: 14),
            label: const Text('Schedule'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brandBlue,
              side: const BorderSide(color: _brandBlue, width: 1.1),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Tertiary: Map Pin
        IconButton(
          onPressed: onViewOnMap,
          icon: const Icon(Icons.explore_outlined, size: 20, color: _brandBlue),
          tooltip: 'Map Location',
          splashRadius: 20,
        ),
      ],
    );
  }
}