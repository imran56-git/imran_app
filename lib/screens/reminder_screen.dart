import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/reminder_service.dart';
import '../../widgets/success_toast.dart';
import 'diary_screen.dart';

class ReminderScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String? prefillStudentId;
  final String? prefillStudentName;
  final double? prefillAmount;
  final void Function(String studentId, String studentName, double amount)? onCreateDiary;

  const ReminderScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    this.prefillStudentId,
    this.prefillStudentName,
    this.prefillAmount,
    this.onCreateDiary,
  });

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final ReminderService _reminderService = ReminderService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  Map<String, dynamic>? _foundStudent;
  bool _isSearching = false;
  bool _isSending = false;
  bool _hasActiveReminder = false;
  bool _isRecurring = true;
  late String _selectedMonth;
  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 5));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 16, minute: 0);

  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  final List<String> _months = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    final nowIst = _nowInIst();
    _selectedMonth = _months[nowIst.month - 1];
    _selectedDueDate = DateTime(nowIst.year, nowIst.month, nowIst.day).add(const Duration(days: 5));

    if (widget.prefillAmount != null && widget.prefillAmount! > 0) {
      _amountController.text = widget.prefillAmount! % 1 == 0
          ? widget.prefillAmount!.toInt().toString()
          : widget.prefillAmount!.toStringAsFixed(2);
    }

    if (widget.prefillStudentId != null && widget.prefillStudentId!.trim().isNotEmpty) {
      _searchController.text = widget.prefillStudentId!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPrefilledStudent();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  DateTime _nowInIst() {
    return DateTime.now().toUtc().add(_istOffset);
  }

  /// Converts the user's chosen IST date & time (at :00 seconds) into the exact UTC DateTime.
  DateTime _calculateNextRunUtc({
    required DateTime dueDate,
    required TimeOfDay time,
  }) {
    final istWallClockAsUtc = DateTime.utc(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      time.hour,
      time.minute,
      0,
      0,
    );
    return istWallClockAsUtc.subtract(_istOffset);
  }

  String _formatDateDdMmYyyy(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _formatHourMinute(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTime24To12(int hour24, int minute) {
    final isAm = hour24 < 12;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minStr ${isAm ? 'AM' : 'PM'}';
  }

  Future<void> _loadPrefilledStudent() async {
    final prefillId = widget.prefillStudentId?.trim() ?? '';
    if (prefillId.isEmpty || !mounted) return;

    setState(() {
      _isSearching = true;
      _foundStudent = null;
      _hasActiveReminder = false;
    });

    try {
      Map<String, dynamic>? student = await _reminderService.searchStudentById(prefillId);
      student ??= {
        'uid': prefillId,
        'name': (widget.prefillStudentName != null && widget.prefillStudentName!.trim().isNotEmpty)
            ? widget.prefillStudentName!.trim()
            : 'Student',
      };

      final String sUid = (student['uid'] ?? prefillId).toString();
      final bool alreadyActive = await _checkIfActiveReminderExists(sUid);

      if (!mounted) return;
      setState(() {
        _foundStudent = student;
        _isSearching = false;
        _hasActiveReminder = alreadyActive;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _foundStudent = {
          'uid': prefillId,
          'name': (widget.prefillStudentName != null && widget.prefillStudentName!.trim().isNotEmpty)
              ? widget.prefillStudentName!.trim()
              : 'Student',
        };
        _isSearching = false;
      });
    }
  }

  void _showErrorPopup(String title, String message) {
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, a1, a2) => const SizedBox(),
      transitionBuilder: (context, anim, a2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(
              opacity: anim,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                    color: Colors.redAccent,
                  ),
                ),
                content: Text(
                  message,
                  style: const TextStyle(fontSize: 14.5, color: Colors.black87, height: 1.4),
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _checkIfActiveReminderExists(String studentId, {String? excludeReminderId}) async {
    try {
      final querySnapshot = await _firestore
          .collection('fee_reminders')
          .where('teacherId', isEqualTo: widget.currentUserId)
          .where('studentId', isEqualTo: studentId)
          .get();

      return querySnapshot.docs.any((doc) {
        if (excludeReminderId != null && doc.id == excludeReminderId) return false;
        return doc.data()['isActive'] == true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkIfTuitionDiaryExists(String studentId) async {
    try {
      final querySnapshot = await _firestore
          .collection('student_fees')
          .where('teacherId', isEqualTo: widget.currentUserId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  void _searchStudent() async {
    FocusScope.of(context).unfocus();
    final searchId = _searchController.text.trim();
    if (searchId.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundStudent = null;
      _hasActiveReminder = false;
    });

    try {
      final student = await _reminderService.searchStudentById(searchId);

      if (!mounted) return;

      if (student == null) {
        setState(() => _isSearching = false);
        _showErrorPopup(
          'Student Not Found',
          'No student registered with UID: $searchId\nPlease verify the student UID and try again.',
        );
        return;
      }

      final String sUid = (student['uid'] ?? searchId).toString();
      final bool alreadyActive = await _checkIfActiveReminderExists(sUid);

      if (!mounted) return;

      setState(() {
        _foundStudent = student;
        _isSearching = false;
        _hasActiveReminder = alreadyActive;
      });

      if (alreadyActive) {
        _showErrorPopup(
          'Active Reminder Exists',
          'An active fee reminder is already scheduled for ${student['name'] ?? 'this student'}.\n\nYou cannot create multiple active reminders for the same student. Please manage it under "Active Reminders" below.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
        _showErrorPopup('Query Error', 'Unable to retrieve student data. Please check network connection.');
      }
    }
  }

  void _showScrollWheelTimePicker() {
    int tempHour = _selectedTime.hourOfPeriod == 0 ? 12 : _selectedTime.hourOfPeriod;
    int tempMinute = _selectedTime.minute;
    bool isAm = _selectedTime.period == DayPeriod.am;

    final FixedExtentScrollController hourController =
        FixedExtentScrollController(initialItem: tempHour - 1);
    final FixedExtentScrollController minuteController =
        FixedExtentScrollController(initialItem: tempMinute);
    final FixedExtentScrollController periodController =
        FixedExtentScrollController(initialItem: isAm ? 0 : 1);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim, a2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              title: const Center(
                child: Text(
                  'Set Reminder Time (IST)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E3A8A)),
                ),
              ),
              content: SizedBox(
                height: 180,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      child: CupertinoPicker(
                        scrollController: hourController,
                        itemExtent: 42,
                        selectionOverlay: Container(
                          decoration: BoxDecoration(
                            border: Border.symmetric(
                              horizontal: BorderSide(color: Colors.blue.shade300, width: 1.5),
                            ),
                          ),
                        ),
                        onSelectedItemChanged: (index) {
                          HapticFeedback.selectionClick();
                          tempHour = index + 1;
                        },
                        children: List.generate(
                          12,
                          (i) => Center(
                            child: Text(
                              '${i + 1}'.padLeft(2, '0'),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Text(':', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(
                      width: 60,
                      child: CupertinoPicker(
                        scrollController: minuteController,
                        itemExtent: 42,
                        selectionOverlay: Container(
                          decoration: BoxDecoration(
                            border: Border.symmetric(
                              horizontal: BorderSide(color: Colors.blue.shade300, width: 1.5),
                            ),
                          ),
                        ),
                        onSelectedItemChanged: (index) {
                          HapticFeedback.selectionClick();
                          tempMinute = index;
                        },
                        children: List.generate(
                          60,
                          (i) => Center(
                            child: Text(
                              '$i'.padLeft(2, '0'),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 68,
                      child: CupertinoPicker(
                        scrollController: periodController,
                        itemExtent: 42,
                        selectionOverlay: Container(
                          decoration: BoxDecoration(
                            border: Border.symmetric(
                              horizontal: BorderSide(color: Colors.blue.shade300, width: 1.5),
                            ),
                          ),
                        ),
                        onSelectedItemChanged: (index) {
                          HapticFeedback.selectionClick();
                          isAm = index == 0;
                        },
                        children: const [
                          Center(
                            child: Text(
                              'AM',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ),
                          Center(
                            child: Text(
                              'PM',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    int convertedHour = tempHour;
                    if (isAm && convertedHour == 12) convertedHour = 0;
                    if (!isAm && convertedHour != 12) convertedHour += 12;

                    setState(() {
                      _selectedTime = TimeOfDay(hour: convertedHour, minute: tempMinute);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Set Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      hourController.dispose();
      minuteController.dispose();
      periodController.dispose();
    });
  }

  Future<void> _showCreateDiaryRecommendationSheet({
    required String studentId,
    required String studentName,
    required double amount,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.menu_book_rounded, color: Colors.blue[800], size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Tuition Diary?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Smart Automatic Ledger Sync',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    '$studentName does not have a Tuition Diary entry yet.\n\n'
                    'Creating a Tuition Diary will automatically add ₹${amount % 1 == 0 ? amount.toInt() : amount.toStringAsFixed(2)} to pending dues and record a monthly ledger entry whenever this scheduled reminder fires.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade800,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 1,
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                        label: const Text('Create Diary', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          if (widget.onCreateDiary != null) {
                            widget.onCreateDiary!(studentId, studentName, amount);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DiaryScreen(
                                  currentUserId: widget.currentUserId,
                                  currentUserName: widget.currentUserName,
                                  prefillStudentId: studentId,
                                  prefillStudentName: studentName,
                                  prefillAmount: amount,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sendReminder() async {
    FocusScope.of(context).unfocus();
    if (_foundStudent == null || _amountController.text.trim().isEmpty) return;

    final double? amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showErrorPopup('Invalid Amount', 'Please enter a valid fee amount greater than 0.');
      return;
    }

    final DateTime nextRunUtc = _calculateNextRunUtc(
      dueDate: _selectedDueDate,
      time: _selectedTime,
    );
    final DateTime nowUtc = DateTime.now().toUtc();

    if (nextRunUtc.isBefore(nowUtc.subtract(const Duration(seconds: 30)))) {
      _showErrorPopup(
        'Selected Time Has Passed',
        'The chosen date and time in IST is already in the past. Please choose a future time so the cloud scheduler can deliver it on time.',
      );
      return;
    }

    final String targetStudentId = (_foundStudent!['uid'] ?? _searchController.text.trim()).toString();
    final String targetStudentName = (_foundStudent!['name'] ?? 'Student').toString().trim();
    final String teacherName = widget.currentUserName.trim().isEmpty ? 'Teacher' : widget.currentUserName.trim();

    setState(() => _isSending = true);

    try {
      final bool alreadyExists = await _checkIfActiveReminderExists(targetStudentId);

      if (alreadyExists) {
        if (mounted) {
          setState(() {
            _isSending = false;
            _hasActiveReminder = true;
          });
          _showErrorPopup(
            'Active Reminder Already Exists',
            'An active fee reminder is already scheduled for $targetStudentName.\n\nA teacher can only have one active reminder per student. Please manage the existing reminder from "Active Reminders".',
          );
        }
        return;
      }

      final String reminderId = '${widget.currentUserId}_${targetStudentId}_${DateTime.now().millisecondsSinceEpoch}';
      final String dueDateText = _formatDateDdMmYyyy(_selectedDueDate);

      await _firestore.collection('fee_reminders').doc(reminderId).set({
        'reminderId': reminderId,
        'teacherId': widget.currentUserId,
        'teacherName': teacherName,
        'studentId': targetStudentId,
        'studentName': targetStudentName,
        'amount': amount,
        'monthName': _selectedMonth,
        'dueDateText': dueDateText,
        'dayOfMonth': _selectedDueDate.day,
        'hour': _selectedTime.hour,
        'minute': _selectedTime.minute,
        'isRecurring': _isRecurring,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'nextRunAt': Timestamp.fromDate(nextRunUtc),
      });

      final bool hasDiary = await _checkIfTuitionDiaryExists(targetStudentId);

      if (!mounted) return;

      SuccessToast.show(context, 'Reminder Scheduled Successfully');
      setState(() {
        _foundStudent = null;
        _searchController.clear();
        _amountController.clear();
        _isSending = false;
        _hasActiveReminder = false;
      });

      if (!hasDiary) {
        await _showCreateDiaryRecommendationSheet(
          studentId: targetStudentId,
          studentName: targetStudentName,
          amount: amount,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSending = false);
        _showErrorPopup('Failed', 'Could not schedule the reminder. Please try again.');
      }
    }
  }

  Future<void> _toggleReminderStatus({
    required String docId,
    required String studentId,
    required String studentName,
    required bool targetActive,
  }) async {
    try {
      if (targetActive) {
        final bool anotherActive = await _checkIfActiveReminderExists(
          studentId,
          excludeReminderId: docId,
        );
        if (anotherActive) {
          _showErrorPopup(
            'Active Reminder Conflict',
            'Another active reminder already exists for $studentName. Please pause or delete it first.',
          );
          return;
        }
      }

      await _firestore.collection('fee_reminders').doc(docId).update({
        'isActive': targetActive,
      });

      if (mounted) {
        SuccessToast.show(
          context,
          targetActive ? 'Reminder Activated' : 'Reminder Paused',
        );
      }
    } catch (_) {
      _showErrorPopup('Update Failed', 'Could not update reminder status.');
    }
  }

  Future<void> _deleteReminder(String docId, String studentName) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Reminder?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete the scheduled reminder for $studentName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('fee_reminders').doc(docId).delete();
      if (mounted) {
        SuccessToast.show(context, 'Reminder Deleted');
      }
    } catch (_) {
      _showErrorPopup('Delete Failed', 'Could not delete the reminder. Please try again.');
    }
  }

  void _showActiveRemindersSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F9FC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 14, 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 42,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.notifications_active_rounded, color: Colors.blue[800], size: 24),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Scheduled Fee Reminders',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(sheetContext),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('fee_reminders')
                          .where('teacherId', isEqualTo: widget.currentUserId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return const Center(child: Text('Unable to load reminders.'));
                        }

                        final docs = [...(snapshot.data?.docs ?? [])];
                        docs.sort((a, b) {
                          final aMap = a.data() as Map<String, dynamic>;
                          final bMap = b.data() as Map<String, dynamic>;
                          final aActive = aMap['isActive'] == true ? 1 : 0;
                          final bActive = bMap['isActive'] == true ? 1 : 0;
                          if (aActive != bActive) return bActive.compareTo(aActive);
                          final aTs = aMap['createdAt'] as Timestamp?;
                          final bTs = bMap['createdAt'] as Timestamp?;
                          return (bTs?.millisecondsSinceEpoch ?? 0)
                              .compareTo(aTs?.millisecondsSinceEpoch ?? 0);
                        });

                        if (docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event_note_rounded, size: 52, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No fee reminders scheduled yet.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final String studentId = (data['studentId'] ?? '').toString();
                            final String studentName = (data['studentName'] ?? 'Student').toString();
                            final double amount = (data['amount'] is num)
                                ? (data['amount'] as num).toDouble()
                                : double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
                            final String monthName = (data['monthName'] ?? '').toString();
                            final String dueDateText = (data['dueDateText'] ?? '').toString();
                            final int hour = (data['hour'] is num) ? (data['hour'] as num).toInt() : 16;
                            final int minute = (data['minute'] is num) ? (data['minute'] as num).toInt() : 0;
                            final bool isRecurring = data['isRecurring'] == true;
                            final bool isActive = data['isActive'] == true;
                            final Timestamp? nextRunTs = data['nextRunAt'] as Timestamp?;
                            String nextRunLabel = dueDateText;
                            if (nextRunTs != null) {
                              final nextIst = nextRunTs.toDate().toUtc().add(_istOffset);
                              nextRunLabel =
                                  '${_formatDateDdMmYyyy(nextIst)} at ${_formatTime24To12(nextIst.hour, nextIst.minute)}';
                            }

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isActive ? Colors.blue.shade100 : Colors.grey.shade200,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              studentName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1E293B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '₹${amount % 1 == 0 ? amount.toInt() : amount.toStringAsFixed(2)} • $monthName',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.blue[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch.adaptive(
                                        value: isActive,
                                        activeColor: const Color(0xFF10B981),
                                        onChanged: (val) => _toggleReminderStatus(
                                          docId: doc.id,
                                          studentId: studentId,
                                          studentName: studentName,
                                          targetActive: val,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                        tooltip: 'Delete reminder',
                                        onPressed: () => _deleteReminder(doc.id, studentName),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isActive ? const Color(0xFFECFDF5) : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isActive ? 'Active' : 'Paused',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: isActive ? const Color(0xFF059669) : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isRecurring ? const Color(0xFFEFF6FF) : Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isRecurring ? 'Monthly Auto-Repeat' : 'One-Time',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: isRecurring ? Colors.blue[800] : Colors.orange.shade800,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Text(
                                          '${_formatTime24To12(hour, minute)} IST',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Next Run: $nextRunLabel IST',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAm = _selectedTime.period == DayPeriod.am;
    final nowIst = _nowInIst();
    final todayIst = DateTime(nowIst.year, nowIst.month, nowIst.day);
    final safeInitialDate = _selectedDueDate.isBefore(todayIst) ? todayIst : _selectedDueDate;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Fee Reminder',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 19),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Student',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B1B1B)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Enter Student User ID',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                            prefixIcon: Icon(Icons.tag_rounded, color: Colors.blue[800], size: 22),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onSubmitted: (_) => _searchStudent(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: _isSearching ? null : _searchStudent,
                        child: _isSearching
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Icon(Icons.search_rounded, size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_foundStudent != null) ...[
              const SizedBox(height: 24),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 20),
                    child: child,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasActiveReminder)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade300, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'An active reminder already exists for this student. You cannot schedule a duplicate.',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.shade50,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: (_foundStudent!['profileImageUrl'] != null &&
                                        _foundStudent!['profileImageUrl'].toString().isNotEmpty)
                                    ? Image.network(
                                        _foundStudent!['profileImageUrl'].toString(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Icon(Icons.person_rounded, color: Colors.blue[800], size: 26),
                                      )
                                    : Icon(Icons.person_rounded, color: Colors.blue[800], size: 26),
                              ),
                            ),
                            title: Text(
                              _foundStudent!['name'] ?? 'Student',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Color(0xFF1B1B1B),
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                _foundStudent!['uid'] ?? 'No ID',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey[600],
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          ),
                          TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Amount (₹)',
                              labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                              prefixIcon: Icon(Icons.currency_rupee_rounded, color: Colors.blue[800], size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 18),
                          DropdownButtonFormField<String>(
                            value: _selectedMonth,
                            decoration: InputDecoration(
                              labelText: 'Month',
                              labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
                              ),
                            ),
                            items: _months
                                .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m, style: const TextStyle(fontSize: 14)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedMonth = val);
                            },
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: safeInitialDate,
                                      firstDate: todayIst,
                                      lastDate: todayIst.add(const Duration(days: 365)),
                                    );
                                    if (picked != null && mounted) {
                                      setState(() => _selectedDueDate = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Due Date',
                                      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDateDdMmYyyy(_selectedDueDate),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        Icon(Icons.calendar_today_rounded, size: 18, color: Colors.blue[800]),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: InkWell(
                                  onTap: _showScrollWheelTimePicker,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Send Time (IST)',
                                      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _formatHourMinute(_selectedTime),
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isAm ? Colors.blue.shade50 : Colors.indigo.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isAm ? Colors.blue.shade300 : Colors.indigo.shade300,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                isAm ? 'AM' : 'PM',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: isAm ? Colors.blue.shade800 : Colors.indigo.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Icon(Icons.access_time_rounded, size: 18, color: Colors.blue[800]),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.repeat_rounded, color: Colors.blue[800], size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Monthly Auto-Repeat',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      Text(
                                        _isRecurring
                                            ? 'Repeats automatically on day ${_selectedDueDate.day} every month'
                                            : 'Sends once on ${_formatDateDdMmYyyy(_selectedDueDate)}',
                                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _isRecurring,
                                  activeColor: Colors.blue[800],
                                  onChanged: (val) => setState(() => _isRecurring = val),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Official Channel Preview',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B1B1B)),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(
                                  'assets/images/app_logo.png',
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => CircleAvatar(
                                    radius: 15,
                                    backgroundColor: Colors.teal.shade50,
                                    child: const Icon(Icons.verified_rounded, color: Colors.teal, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'FYBTT official',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Image.asset(
                                'assets/images/Verified_Batch.png',
                                width: 14,
                                height: 14,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.verified_rounded, color: Color(0xFF0284C7), size: 14),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: const Text(
                                  'Official Notice',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          ),
                          Text(
                            "Hello ${_foundStudent!['name'] ?? 'Student'},\n\n"
                            "This is an official tuition fee reminder on behalf of ${widget.currentUserName.isEmpty ? 'Teacher' : widget.currentUserName}.\n"
                            "Tuition fee for $_selectedMonth is due.\n\n"
                            "Amount: ₹${_amountController.text.isEmpty ? '0' : _amountController.text}\n"
                            "Due Date: ${_formatDateDdMmYyyy(_selectedDueDate)}\n"
                            "Scheduled Transmission: ${_formatHourMinute(_selectedTime)} ${isAm ? 'AM' : 'PM'} IST\n\n"
                            "Please complete the payment promptly.\n"
                            "Thank you,\nFYBTT Official Desk",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                              height: 1.45,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _hasActiveReminder ? Colors.grey.shade400 : const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        onPressed:
                            _isSending || _amountController.text.trim().isEmpty || _hasActiveReminder
                                ? null
                                : _sendReminder,
                        icon: _isSending
                            ? const SizedBox.shrink()
                            : const Icon(Icons.calendar_month_rounded, size: 20),
                        label: _isSending
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                _hasActiveReminder ? 'REMINDER ALREADY ACTIVE' : 'SCHEDULE REMINDER',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),
            GestureDetector(
              onTap: _showActiveRemindersSheet,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[800]!, Colors.blue[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.25),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Reminders',
                            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('fee_reminders')
                                .where('teacherId', isEqualTo: widget.currentUserId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              int activeCount = 0;
                              if (snapshot.hasData) {
                                activeCount = snapshot.data!.docs.where((d) {
                                  final data = d.data() as Map<String, dynamic>;
                                  return data['isActive'] == true;
                                }).length;
                              }
                              return Text(
                                activeCount > 0
                                    ? 'You have $activeCount active scheduled reminder${activeCount == 1 ? '' : 's'}'
                                    : 'View and manage scheduled reminders',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}