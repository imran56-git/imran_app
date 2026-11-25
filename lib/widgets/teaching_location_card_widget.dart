import 'package:flutter/material.dart';
import '../models/teacher_location_model.dart';
import '../models/teaching_batch_model.dart';
import '../services/teacher_location_service.dart';

class TeachingLocationCardWidget extends StatefulWidget {
  final TeacherLocationModel location;
  final bool isOwner;
  final double? studentDistanceKm;
  final int? estimatedTravelMinutes;
  final VoidCallback? onViewOnMap;
  final VoidCallback? onViewSchedule;
  final VoidCallback? onGetDirections;
  final VoidCallback? onEditLocation;
  final VoidCallback? onManageBatches;
  final bool initiallyExpanded;

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
    this.initiallyExpanded = false,
  });

  @override
  State<TeachingLocationCardWidget> createState() => _TeachingLocationCardWidgetState();
}

class _TeachingLocationCardWidgetState extends State<TeachingLocationCardWidget> {
  static const Color _navy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _emerald = Color(0xFF059669);
  static const Color _amber = Color(0xFFD97706);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _mutedSlate = Color(0xFF64748B);
  static const Color _surfaceSlate = Color(0xFFF8FAFC);

  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  String get _resolvedAddress {
    final String full = widget.location.fullAddress;
    if (full.trim().isNotEmpty) return full;
    try {
      final dynamic dynamicLoc = widget.location;
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
        return 'Offline';
      case 'hybrid':
        return 'Hybrid';
      case 'online':
        return 'Online';
      default:
        return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.location.isActive != false;
    final bool isVerified = widget.location.verificationStatus == 'verified';

    return Opacity(
      opacity: isActive ? 1.0 : 0.88,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? _cardBorder : Colors.red.shade100,
            width: 1.1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              offset: Offset(0, 2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _brandBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getLocationTypeIcon(widget.location.locationType),
                        size: 20,
                        color: _brandBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.location.locationName,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: _navy,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, size: 14, color: _emerald),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _formatLocationType(widget.location.locationType),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: _mutedSlate,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.studentDistanceKm != null) ...[
                                const SizedBox(width: 5),
                                Text(
                                  '• ${widget.studentDistanceKm!.toStringAsFixed(1)} KM',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: _accentBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 5),
                              Text(
                                '• ${_formatTeachingMode(widget.location.teachingMode)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _mutedSlate,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (widget.isOwner)
                      _buildOwnerDropdownMenu(context),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: _mutedSlate,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1, color: _cardBorder),
                        if (!isActive) _buildInactiveNotice(),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFullAddressRow(),
                              const SizedBox(height: 10),
                              _buildBatchAndSchedulePreview(),
                              if ((widget.location.subjects?.isNotEmpty ?? false) ||
                                  (widget.location.classes?.isNotEmpty ?? false)) ...[
                                const SizedBox(height: 10),
                                _buildTagsSection(),
                              ],
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: _cardBorder),
                              const SizedBox(height: 10),
                              _buildActionButtons(),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      color: const Color(0xFFFEF2F2),
      child: Row(
        children: [
          Icon(Icons.pause_circle_outline, size: 15, color: Colors.red.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Centre Temporarily Inactive (Hidden from Public Search)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullAddressRow() {
    final String addressText = _resolvedAddress;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.location_on, size: 15, color: Color(0xFFEF4444)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            addressText.isNotEmpty ? addressText : 'Address details unavailable',
            style: const TextStyle(
              fontSize: 12.5,
              color: _mutedSlate,
              height: 1.35,
            ),
          ),
        ),
        if (!widget.isOwner && widget.studentDistanceKm != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _surfaceSlate,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.near_me_outlined, size: 12, color: _accentBlue),
                const SizedBox(width: 4),
                Text(
                  widget.estimatedTravelMinutes != null
                      ? '${widget.studentDistanceKm!.toStringAsFixed(1)} KM (${widget.estimatedTravelMinutes}m)'
                      : '${widget.studentDistanceKm!.toStringAsFixed(1)} KM',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOwnerDropdownMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: _mutedSlate),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        if (val == 'edit' && widget.onEditLocation != null) {
          widget.onEditLocation!();
        } else if (val == 'batches' && widget.onManageBatches != null) {
          widget.onManageBatches!();
        } else if (val == 'map' && widget.onViewOnMap != null) {
          widget.onViewOnMap!();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 17, color: _navy),
              SizedBox(width: 10),
              Text('Edit Centre Details', style: TextStyle(fontSize: 13, color: _navy)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'batches',
          child: Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 17, color: _navy),
              SizedBox(width: 10),
              Text('Manage Batches & Timetable', style: TextStyle(fontSize: 13, color: _navy)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'map',
          child: Row(
            children: [
              Icon(Icons.map_outlined, size: 17, color: _navy),
              SizedBox(width: 10),
              Text('View on Map', style: TextStyle(fontSize: 13, color: _navy)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBatchAndSchedulePreview() {
    return StreamBuilder<List<TeachingBatchModel>>(
      stream: TeacherLocationService().getBatchesStream(
        widget.location.teacherId,
        widget.location.id,
      ),
      builder: (context, snapshot) {
        final batches = snapshot.data ?? [];

        if (batches.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _surfaceSlate,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _cardBorder.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 13, color: _mutedSlate),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.isOwner
                        ? 'No active batches configured yet. Tap "Manage" to set timings.'
                        : 'Contact educator directly for batch timings and availability.',
                    style: const TextStyle(fontSize: 11, color: _mutedSlate),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _surfaceSlate,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            children: [
              _buildMetricChip(
                icon: Icons.groups_outlined,
                text: '$activeBatchCount ${activeBatchCount == 1 ? 'Batch' : 'Batches'}',
                color: _brandBlue,
              ),
              if (subjects.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMetricChip(
                    icon: Icons.menu_book_outlined,
                    text: subjects.take(2).join(', '),
                    color: _navy,
                  ),
                ),
              ],
              if (classLevels.isNotEmpty) ...[
                const SizedBox(width: 6),
                _buildMetricChip(
                  icon: Icons.school_outlined,
                  text: classLevels.first,
                  color: _amber,
                ),
              ] else if (activeBatches.isNotEmpty) ...[
                const SizedBox(width: 6),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
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
                fontSize: 10.5,
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
    final subjects = widget.location.subjects ?? [];
    final classes = widget.location.classes ?? [];

    return Wrap(
      spacing: 6,
      runSpacing: 5,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor ?? Colors.transparent),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (widget.isOwner) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: widget.onManageBatches,
              icon: const Icon(Icons.date_range, size: 15),
              label: const Text('Manage Batches'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: widget.onEditLocation,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _cardBorder, width: 1.1),
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Edit', style: TextStyle(color: _navy)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: widget.onViewOnMap,
            icon: const Icon(Icons.map_outlined, size: 18, color: _mutedSlate),
            tooltip: 'View on Map',
            splashRadius: 18,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: widget.onGetDirections,
            icon: const Icon(Icons.directions, size: 15),
            label: const Text('Directions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: OutlinedButton.icon(
            onPressed: widget.onViewSchedule,
            icon: const Icon(Icons.calendar_today, size: 13),
            label: const Text('Schedule'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brandBlue,
              side: const BorderSide(color: _brandBlue, width: 1.1),
              padding: const EdgeInsets.symmetric(vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: widget.onViewOnMap,
          icon: const Icon(Icons.explore_outlined, size: 18, color: _brandBlue),
          tooltip: 'Map Location',
          splashRadius: 18,
        ),
      ],
    );
  }
}