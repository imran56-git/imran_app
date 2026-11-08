import 'package:flutter/material.dart';
import '../models/teacher_location_model.dart';
import '../models/teaching_batch_model.dart';
import '../models/teaching_schedule_model.dart';
import '../services/teacher_location_service.dart';

class LocationBatchScheduleScreen extends StatefulWidget {
  final TeacherLocationModel location;

  const LocationBatchScheduleScreen({
    super.key,
    required this.location,
  });

  @override
  State<LocationBatchScheduleScreen> createState() => _LocationBatchScheduleScreenState();
}

class _LocationBatchScheduleScreenState extends State<LocationBatchScheduleScreen>
    with SingleTickerProviderStateMixin {
  // Theme Color Palette
  static const Color _navy = Color(0xFF0F172A);
  static const Color _brandBlue = Color(0xFF1E4C7A);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _accentAmber = Color(0xFFF59E0B);
  static const Color _backgroundSlate = Color(0xFFF8FAFC);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _mutedSlate = Color(0xFF64748B);

  late TabController _tabController;
  final TeacherLocationService _locationService = TeacherLocationService();

  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late String _selectedDay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    // Default to current weekday
    final currentWeekdayIndex = DateTime.now().weekday - 1;
    _selectedDay = _daysOfWeek[currentWeekdayIndex.clamp(0, 6)];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper to parse "HH:mm AM/PM" or "HH:mm" into minutes since midnight
  int _timeToMinutes(String timeStr) {
    try {
      final sanitized = timeStr.trim().toUpperCase();
      final isPm = sanitized.contains('PM');
      final isAm = sanitized.contains('AM');
      final clean = sanitized.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = clean.split(':');
      if (parts.isEmpty) return 0;
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return (hour * 60) + minute;
    } catch (_) {
      return 0;
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  String _getSlotPeriod(String startTimeStr) {
    final minutes = _timeToMinutes(startTimeStr);
    if (minutes < 720) {
      return 'Morning'; // Before 12 PM
    } else if (minutes < 1020) {
      return 'Afternoon'; // 12 PM to 5 PM
    } else {
      return 'Evening'; // After 5 PM
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundSlate,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWeeklyTimetableTab(),
          _buildBatchesCapacityTab(),
        ],
      ),
      floatingActionButton: _buildContextualFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: _navy, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.location.locationName,
            style: const TextStyle(
              color: _navy,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            widget.location.address,
            style: const TextStyle(
              color: _mutedSlate,
              fontSize: 11.5,
              fontWeight: FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(49.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _cardBorder, width: 1)),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: _brandBlue,
            indicatorWeight: 3,
            labelColor: _brandBlue,
            unselectedLabelColor: _mutedSlate,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
            tabs: const [
              Tab(text: 'Weekly Timetable'),
              Tab(text: 'Batches & Capacity'),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildContextualFAB() {
    if (_tabController.index == 0) {
      return FloatingActionButton.extended(
        backgroundColor: _brandBlue,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_alarm, size: 20),
        label: const Text('Add Slot', style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () => _openScheduleSlotModal(),
      );
    } else {
      return FloatingActionButton.extended(
        backgroundColor: _brandBlue,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.group_add, size: 20),
        label: const Text('Create Batch', style: TextStyle(fontWeight: FontWeight.w600)),
        onPressed: () => _openBatchModal(),
      );
    }
  }

  // ===========================================================================
  // TAB 1: WEEKLY TIMETABLE
  // ===========================================================================

  Widget _buildWeeklyTimetableTab() {
    return StreamBuilder<List<TeachingScheduleModel>>(
      stream: _locationService.getSchedulesStream(
        widget.location.teacherId,
        widget.location.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _brandBlue));
        }

        final allSchedules = snapshot.data ?? [];
        final daySchedules = allSchedules
            .where((s) => s.dayOfWeek.toLowerCase() == _selectedDay.toLowerCase())
            .toList()
          ..sort((a, b) => _timeToMinutes(a.startTime).compareTo(_timeToMinutes(b.startTime)));

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDaySelector(),
              const SizedBox(height: 16),
              _buildTimetableActionBar(daySchedules, allSchedules),
              const SizedBox(height: 16),
              if (daySchedules.isEmpty)
                _buildEmptyDayState()
              else ...[
                _buildSlotSection('Morning', 'Slots before 12:00 PM', daySchedules),
                _buildSlotSection('Afternoon', '12:00 PM to 05:00 PM', daySchedules),
                _buildSlotSection('Evening', 'After 05:00 PM', daySchedules),
              ],
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: _daysOfWeek.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final day = _daysOfWeek[index];
          final isSelected = day == _selectedDay;
          final shortName = day.substring(0, 3);

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? _brandBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                shortName,
                style: TextStyle(
                  color: isSelected ? Colors.white : _navy,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimetableActionBar(
    List<TeachingScheduleModel> daySchedules,
    List<TeachingScheduleModel> allSchedules,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_selectedDay Schedule',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            Text(
              '${daySchedules.length} slot${daySchedules.length == 1 ? '' : 's'} assigned',
              style: const TextStyle(fontSize: 12, color: _mutedSlate),
            ),
          ],
        ),
        if (daySchedules.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => _showCopyScheduleDialog(daySchedules, allSchedules),
            icon: const Icon(Icons.copy_all, size: 16),
            label: const Text('Copy to Other Days'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brandBlue,
              side: const BorderSide(color: _brandBlue, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _buildSlotSection(
    String period,
    String sublabel,
    List<TeachingScheduleModel> allDaySlots,
  ) {
    final periodSlots = allDaySlots.where((slot) => _getSlotPeriod(slot.startTime) == period).toList();

    if (periodSlots.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: period == 'Morning'
                      ? _accentAmber
                      : period == 'Afternoon'
                          ? _accentBlue
                          : _brandBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                period,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: _navy),
              ),
              const SizedBox(width: 8),
              Text('• $sublabel', style: const TextStyle(fontSize: 11.5, color: _mutedSlate)),
            ],
          ),
          const SizedBox(height: 10),
          ...periodSlots.map((slot) => _buildScheduleSlotCard(slot, allDaySlots)),
        ],
      ),
    );
  }

  Widget _buildScheduleSlotCard(
    TeachingScheduleModel slot,
    List<TeachingScheduleModel> daySlots,
  ) {
    final status = (slot.status ?? 'active').toLowerCase();
    Color statusBg = const Color(0xFFECFDF5);
    Color statusColor = const Color(0xFF047857);

    if (status == 'holiday') {
      statusBg = const Color(0xFFFEF3C7);
      statusColor = const Color(0xFFB45309);
    } else if (status == 'cancelled') {
      statusBg = const Color(0xFFFEE2E2);
      statusColor = const Color(0xFFB91C1C);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            offset: Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _brandBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        slot.subject,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _brandBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _backgroundSlate,
                        border: Border.all(color: _cardBorder),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        slot.classLevel,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: _mutedSlate),
              const SizedBox(width: 6),
              Text(
                '${slot.startTime} – ${slot.endTime}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.class_outlined, size: 15, color: _mutedSlate),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  slot.batchName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _mutedSlate,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (slot.notes != null && slot.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _backgroundSlate,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: _mutedSlate),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      slot.notes!,
                      style: const TextStyle(fontSize: 11.5, color: _mutedSlate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 12, color: _cardBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => _openScheduleSlotModal(
                  existingSlot: slot,
                  daySlots: daySlots,
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 15, color: _brandBlue),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(fontSize: 12, color: _brandBlue, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => _confirmDeleteSlot(slot),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 15, color: Colors.red.shade600),
                      SizedBox(width: 4),
                      Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _brandBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy, size: 36, color: _brandBlue),
          ),
          const SizedBox(height: 14),
          Text(
            'No Slots for $_selectedDay',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy),
          ),
          const SizedBox(height: 4),
          const Text(
            'There are no teaching slots scheduled on this day.',
            style: TextStyle(fontSize: 12.5, color: _mutedSlate),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openScheduleSlotModal(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Slot Now', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: BATCHES & CAPACITY MANAGEMENT
  // ===========================================================================

  Widget _buildBatchesCapacityTab() {
    return StreamBuilder<List<TeachingBatchModel>>(
      stream: _locationService.getBatchesStream(
        widget.location.teacherId,
        widget.location.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _brandBlue));
        }

        final batches = snapshot.data ?? [];

        if (batches.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _brandBlue.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.group_off_outlined, size: 48, color: _brandBlue),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Batches Configured',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create classroom batches to allocate student limits, subjects, and recurring sessions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _mutedSlate),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _openBatchModal(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create First Batch', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          physics: const BouncingScrollPhysics(),
          itemCount: batches.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == batches.length) {
              return const SizedBox(height: 70); // Bottom padding for FAB
            }
            return _buildBatchCard(batches[index]);
          },
        );
      },
    );
  }

  Widget _buildBatchCard(TeachingBatchModel batch) {
    final maxCapacity = batch.maxCapacity;
    final enrolled = batch.enrolledCount ?? 0;
    final remaining = (maxCapacity - enrolled).clamp(0, maxCapacity);
    final ratio = maxCapacity > 0 ? (enrolled / maxCapacity).clamp(0.0, 1.0) : 0.0;

    Color statusColor;
    String statusLabel;
    Color statusBg;

    if (remaining == 0) {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEE2E2);
      statusLabel = 'Full';
    } else if (remaining <= 3 || ratio >= 0.8) {
      statusColor = _accentAmber;
      statusBg = const Color(0xFFFEF3C7);
      statusLabel = 'Few Seats Left';
    } else {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
      statusLabel = 'Available';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            offset: Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  batch.batchName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _brandBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  batch.subject,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _brandBlue),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _backgroundSlate,
                  border: Border.all(color: _cardBorder),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  batch.classLevel,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _navy),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Capacity Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Capacity: $enrolled / $maxCapacity Seats',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _navy),
              ),
              Text(
                '$remaining seat${remaining == 1 ? '' : 's'} remaining',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: _backgroundSlate,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 12),
          // Days & Timings
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: _mutedSlate),
              const SizedBox(width: 4),
              Text(
                '${batch.startTime} - ${batch.endTime}',
                style: const TextStyle(fontSize: 12, color: _navy, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.date_range, size: 14, color: _mutedSlate),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  batch.days.join(', '),
                  style: const TextStyle(fontSize: 12, color: _mutedSlate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _cardBorder),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _openBatchModal(existingBatch: batch),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Edit Batch', style: TextStyle(fontSize: 12.5)),
                style: TextButton.styleFrom(
                  foregroundColor: _brandBlue,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _confirmDeleteBatch(batch),
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text('Delete', style: TextStyle(fontSize: 12.5)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MODALS & DIALOGS
  // ===========================================================================

  void _openScheduleSlotModal({
    TeachingScheduleModel? existingSlot,
    List<TeachingScheduleModel>? daySlots,
  }) async {
    final batches = await _locationService.getBatches(widget.location.teacherId, widget.location.id);

    if (!mounted) return;
    if (batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create at least one batch before configuring timetable slots.'),
          backgroundColor: _accentAmber,
        ),
      );
      _tabController.animateTo(1);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ScheduleSlotModalSheet(
        location: widget.location,
        selectedDay: _selectedDay,
        availableBatches: batches,
        existingSlot: existingSlot,
        allDaySlots: daySlots ?? [],
        onSave: (newSlot) async {
          // Check conflict
          final conflictingSlots = (daySlots ?? []).where((s) {
            if (existingSlot != null && s.id == existingSlot.id) return false;
            return s.overlapsWith(newSlot);
          }).toList();

          if (conflictingSlots.isNotEmpty) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: _accentAmber, size: 24),
                    SizedBox(width: 8),
                    Text('Timing Conflict Detected', style: TextStyle(fontSize: 16, color: _navy)),
                  ],
                ),
                content: Text(
                  'The slot timing (${newSlot.startTime} – ${newSlot.endTime}) overlaps with "${conflictingSlots.first.batchName}" (${conflictingSlots.first.startTime} – ${conflictingSlots.first.endTime}).\n\nDo you want to proceed and save anyway?',
                  style: const TextStyle(fontSize: 13, color: _mutedSlate, height: 1.4),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Adjust Timings', style: TextStyle(color: _brandBlue)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentAmber,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Save Anyway'),
                  ),
                ],
              ),
            );

            if (confirm != true) return;
          }

          if (existingSlot != null) {
            await _locationService.updateScheduleSlot(newSlot);
          } else {
            await _locationService.addScheduleSlot(newSlot);
          }

          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  existingSlot != null ? 'Slot updated successfully' : 'New slot scheduled',
                ),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        },
      ),
    );
  }

  void _openBatchModal({TeachingBatchModel? existingBatch}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BatchFormModalSheet(
        location: widget.location,
        existingBatch: existingBatch,
        onSave: (batch) async {
          if (existingBatch != null) {
            await _locationService.updateBatch(batch);
          } else {
            await _locationService.addBatch(batch);
          }
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  existingBatch != null ? 'Batch updated successfully' : 'Batch created successfully',
                ),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        },
      ),
    );
  }

  void _showCopyScheduleDialog(
    List<TeachingScheduleModel> sourceSlots,
    List<TeachingScheduleModel> allSchedules,
  ) {
    final otherDays = _daysOfWeek.where((d) => d != _selectedDay).toList();
    final selectedDaysToCopy = <String>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.copy_all, color: _brandBlue, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Copy $_selectedDay to Other Days',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replicate all ${sourceSlots.length} slot(s) from $_selectedDay to the selected days:',
                    style: const TextStyle(fontSize: 12.5, color: _mutedSlate),
                  ),
                  const SizedBox(height: 12),
                  ...otherDays.map((day) {
                    final isChecked = selectedDaysToCopy.contains(day);
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: _brandBlue,
                      title: Text(day, style: const TextStyle(fontSize: 13.5, color: _navy)),
                      value: isChecked,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            selectedDaysToCopy.add(day);
                          } else {
                            selectedDaysToCopy.remove(day);
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: _mutedSlate)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: selectedDaysToCopy.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(context);
                        for (final targetDay in selectedDaysToCopy) {
                          for (final slot in sourceSlots) {
                            final duplicated = slot.copyWith(
                              id: UniqueKey().toString(),
                              dayOfWeek: targetDay,
                              createdAt: DateTime.now(),
                            );
                            await _locationService.addScheduleSlot(duplicated);
                          }
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Copied to ${selectedDaysToCopy.length} day(s) successfully!',
                              ),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        }
                      },
                child: const Text('Copy Slots'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteSlot(TeachingScheduleModel slot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Slot', style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove the ${slot.subject} slot (${slot.startTime})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _mutedSlate)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _locationService.deleteScheduleSlot(slot.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteBatch(TeachingBatchModel batch) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Batch', style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${batch.batchName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _mutedSlate)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _locationService.deleteBatch(batch.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MODAL SHEET: ADD / EDIT SCHEDULE SLOT
// =============================================================================

class _ScheduleSlotModalSheet extends StatefulWidget {
  final TeacherLocationModel location;
  final String selectedDay;
  final List<TeachingBatchModel> availableBatches;
  final TeachingScheduleModel? existingSlot;
  final List<TeachingScheduleModel> allDaySlots;
  final Function(TeachingScheduleModel) onSave;

  const _ScheduleSlotModalSheet({
    required this.location,
    required this.selectedDay,
    required this.availableBatches,
    this.existingSlot,
    required this.allDaySlots,
    required this.onSave,
  });

  @override
  State<_ScheduleSlotModalSheet> createState() => _ScheduleSlotModalSheetState();
}

class _ScheduleSlotModalSheetState extends State<_ScheduleSlotModalSheet> {
  final _formKey = GlobalKey<FormState>();

  late TeachingBatchModel _selectedBatch;
  late String _dayOfWeek;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String _recurrence;
  late String _status;
  final TextEditingController _notesController = TextEditingController();

  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    final slot = widget.existingSlot;

    if (slot != null) {
      _selectedBatch = widget.availableBatches.firstWhere(
        (b) => b.id == slot.batchId,
        orElse: () => widget.availableBatches.first,
      );
      _dayOfWeek = slot.dayOfWeek;
      _startTime = _parseTimeString(slot.startTime);
      _endTime = _parseTimeString(slot.endTime);
      _recurrence = slot.recurrence ?? 'weekly';
      _status = slot.status ?? 'active';
      _notesController.text = slot.notes ?? '';
    } else {
      _selectedBatch = widget.availableBatches.first;
      _dayOfWeek = widget.selectedDay;
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      _endTime = const TimeOfDay(hour: 9, minute: 30);
      _recurrence = 'weekly';
      _status = 'active';
    }
  }

  TimeOfDay _parseTimeString(String timeStr) {
    try {
      final sanitized = timeStr.trim().toUpperCase();
      final isPm = sanitized.contains('PM');
      final isAm = sanitized.contains('AM');
      final clean = sanitized.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = clean.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingSlot != null ? 'Edit Schedule Slot' : 'Add Timetable Slot',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              // Batch Selector
              const Text('Linked Batch *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<TeachingBatchModel>(
                value: _selectedBatch,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: widget.availableBatches.map((b) {
                  return DropdownMenuItem(
                    value: b,
                    child: Text('${b.batchName} (${b.subject} - ${b.classLevel})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBatch = val);
                },
              ),
              const SizedBox(height: 14),
              // Day of the week
              const Text('Day of Week', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _dayOfWeek,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _daysOfWeek.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _dayOfWeek = val);
                },
              ),
              const SizedBox(height: 14),
              // Time pickers
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Time', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: _startTime);
                            if (picked != null) setState(() => _startTime = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Color(0xFF1E4C7A)),
                                const SizedBox(width: 8),
                                Text(_formatTimeOfDay(_startTime), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Time', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: _endTime);
                            if (picked != null) setState(() => _endTime = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Color(0xFF1E4C7A)),
                                const SizedBox(width: 8),
                                Text(_formatTimeOfDay(_endTime), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Status & Recurrence
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Slot Status', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('Active')),
                            DropdownMenuItem(value: 'holiday', child: Text('Holiday')),
                            DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _status = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recurrence', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _recurrence,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                            DropdownMenuItem(value: 'biweekly', child: Text('Bi-Weekly')),
                            DropdownMenuItem(value: 'single', child: Text('One-Time')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _recurrence = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Notes
              const Text('Optional Notes / Room Code', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'e.g., Room 102, bring lab notebooks',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E4C7A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final startFormatted = _formatTimeOfDay(_startTime);
                    final endFormatted = _formatTimeOfDay(_endTime);

                    final newSlot = TeachingScheduleModel(
                      id: widget.existingSlot?.id ?? UniqueKey().toString(),
                      teacherId: widget.location.teacherId,
                      locationId: widget.location.id,
                      batchId: _selectedBatch.id,
                      batchName: _selectedBatch.batchName,
                      subject: _selectedBatch.subject,
                      classLevel: _selectedBatch.classLevel,
                      dayOfWeek: _dayOfWeek,
                      startTime: startFormatted,
                      endTime: endFormatted,
                      status: _status,
                      recurrence: _recurrence,
                      notes: _notesController.text.trim(),
                      createdAt: widget.existingSlot?.createdAt ?? DateTime.now(),
                    );

                    widget.onSave(newSlot);
                  },
                  child: Text(
                    widget.existingSlot != null ? 'Save Slot Changes' : 'Confirm & Schedule',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

// =============================================================================
// MODAL SHEET: ADD / EDIT BATCH FORM
// =============================================================================

class _BatchFormModalSheet extends StatefulWidget {
  final TeacherLocationModel location;
  final TeachingBatchModel? existingBatch;
  final Function(TeachingBatchModel) onSave;

  const _BatchFormModalSheet({
    required this.location,
    this.existingBatch,
    required this.onSave,
  });

  @override
  State<_BatchFormModalSheet> createState() => _BatchFormModalSheetState();
}

class _BatchFormModalSheetState extends State<_BatchFormModalSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _capacityController;
  late String _selectedSubject;
  late String _selectedClass;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late Set<String> _selectedDays;

  final List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final b = widget.existingBatch;
    final availableSubjects = widget.location.subjects ?? ['General'];
    final availableClasses = widget.location.classes ?? ['Class 10'];

    _nameController = TextEditingController(text: b?.batchName ?? '');
    _capacityController = TextEditingController(text: (b?.maxCapacity ?? 20).toString());
    _selectedSubject = b != null && availableSubjects.contains(b.subject)
        ? b.subject
        : availableSubjects.isNotEmpty
            ? availableSubjects.first
            : 'General';
    _selectedClass = b != null && availableClasses.contains(b.classLevel)
        ? b.classLevel
        : availableClasses.isNotEmpty
            ? availableClasses.first
            : 'General';

    _startTime = b != null ? _parseTime(b.startTime) : const TimeOfDay(hour: 16, minute: 0);
    _endTime = b != null ? _parseTime(b.endTime) : const TimeOfDay(hour: 17, minute: 30);
    _selectedDays = Set<String>.from(b?.days ?? ['Mon', 'Wed', 'Fri']);
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final sanitized = timeStr.trim().toUpperCase();
      final isPm = sanitized.contains('PM');
      final isAm = sanitized.contains('AM');
      final clean = sanitized.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = clean.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 16, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = widget.location.subjects ?? ['General'];
    final classes = widget.location.classes ?? ['Standard'];

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingBatch != null ? 'Edit Classroom Batch' : 'Create New Batch',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              // Batch Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Batch Name *',
                  hintText: 'e.g., Morning Olympiad Target',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Batch name required' : null,
              ),
              const SizedBox(height: 14),
              // Subject & Class Selectors
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSubject,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSubject = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedClass,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Class Level',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedClass = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Teaching Days Multi-Select
              const Text('Operating Days', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: _weekDays.map((d) {
                  final isSelected = _selectedDays.contains(d);
                  return FilterChip(
                    label: Text(d),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1E4C7A).withValues(alpha: 0.15),
                    checkmarkColor: const Color(0xFF1E4C7A),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(d);
                        } else {
                          _selectedDays.remove(d);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              // Timings & Capacity
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _startTime);
                        if (picked != null) setState(() => _startTime = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            Text(_formatTimeOfDay(_startTime), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _endTime);
                        if (picked != null) setState(() => _endTime = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            Text(_formatTimeOfDay(_endTime), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Max Seats',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (val) {
                        if (val == null || int.tryParse(val) == null || int.parse(val) <= 0) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E4C7A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    if (_selectedDays.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select at least one teaching day.')),
                      );
                      return;
                    }

                    final batch = TeachingBatchModel(
                      id: widget.existingBatch?.id ?? UniqueKey().toString(),
                      teacherId: widget.location.teacherId,
                      locationId: widget.location.id,
                      batchName: _nameController.text.trim(),
                      subject: _selectedSubject,
                      classLevel: _selectedClass,
                      startTime: _formatTimeOfDay(_startTime),
                      endTime: _formatTimeOfDay(_endTime),
                      days: _selectedDays.toList(),
                      maxCapacity: int.parse(_capacityController.text.trim()),
                      enrolledCount: widget.existingBatch?.enrolledCount ?? 0,
                      isActive: widget.existingBatch?.isActive ?? true,
                      createdAt: widget.existingBatch?.createdAt ?? DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    widget.onSave(batch);
                  },
                  child: Text(
                    widget.existingBatch != null ? 'Save Batch Changes' : 'Create Batch',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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