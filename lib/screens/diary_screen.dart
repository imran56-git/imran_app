import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/reminder_service.dart';
import '../../widgets/success_toast.dart';
import 'diary_history_screen.dart';
import 'reminder_screen.dart';

class DiaryScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String? prefillStudentId;
  final String? prefillStudentName;
  final double? prefillAmount;

  const DiaryScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    this.prefillStudentId,
    this.prefillStudentName,
    this.prefillAmount,
  });

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final ReminderService _reminderService = ReminderService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _monthlyFeeController = TextEditingController();

  Map<String, dynamic>? _foundStudent;
  bool _isSearching = false;
  bool _isSaving = false;
  bool _isLoadingHistory = false;
  bool _isSettlingPayment = false;
  bool _hasUnsavedGridEdits = false;

  late int _selectedYear;
  final List<int> _availableYears = [2024, 2025, 2026, 2027, 2028, 2029];

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

  final Map<String, String> _monthStatuses = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _diarySubscription;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    if (!_availableYears.contains(_selectedYear)) {
      _availableYears.add(_selectedYear);
      _availableYears.sort();
    }
    _resetMonthStatuses();

    if (widget.prefillAmount != null && widget.prefillAmount! > 0) {
      _monthlyFeeController.text = widget.prefillAmount! % 1 == 0
          ? widget.prefillAmount!.toInt().toString()
          : widget.prefillAmount!.toStringAsFixed(2);
    }

    if (widget.prefillStudentId != null &&
        widget.prefillStudentId!.trim().isNotEmpty) {
      _searchController.text = widget.prefillStudentId!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPrefilledStudent();
      });
    }
  }

  void _resetMonthStatuses() {
    for (final month in _months) {
      _monthStatuses[month] = 'NOT_ENROLLED';
    }
  }

  @override
  void dispose() {
    _diarySubscription?.cancel();
    _searchController.dispose();
    _subjectController.dispose();
    _monthlyFeeController.dispose();
    super.dispose();
  }

  double get _monthlyFee =>
      double.tryParse(_monthlyFeeController.text.trim()) ?? 0.0;

  String _normalizeStatus(dynamic rawStatus) {
    final s = (rawStatus ?? '').toString().trim().toUpperCase();
    if (s == 'PAID') return 'PAID';
    if (s == 'DUE' || s == 'PENDING') return 'DUE';
    return 'NOT_ENROLLED';
  }

  String? _findCanonicalMonth(dynamic rawMonth) {
    final cleaned = (rawMonth ?? '').toString().trim().toLowerCase();
    if (cleaned.isEmpty) return null;
    for (final m in _months) {
      if (m.toLowerCase() == cleaned) return m;
    }
    if (cleaned.length >= 3) {
      for (final m in _months) {
        if (m.toLowerCase().startsWith(cleaned.substring(0, 3))) return m;
      }
    }
    return null;
  }

  Map<String, String> _extractStatusMap(Map<String, dynamic> data) {
    final rawMap = (data['monthStatuses'] as Map?) ??
        (data['monthlyStatus'] as Map?) ??
        <String, dynamic>{};

    final Map<String, String> normalized = {
      for (final m in _months) m: 'NOT_ENROLLED',
    };

    rawMap.forEach((key, value) {
      final canonical = _findCanonicalMonth(key);
      if (canonical != null) {
        normalized[canonical] = _normalizeStatus(value);
      }
    });

    return normalized;
  }

  int get _paidMonthsCount =>
      _monthStatuses.values.where((status) => status == 'PAID').length;

  int get _dueMonthsCount =>
      _monthStatuses.values.where((status) => status == 'DUE').length;

  double get _totalPaid => _paidMonthsCount * _monthlyFee;
  double get _gridDue => _dueMonthsCount * _monthlyFee;

  String _currentDiaryDocId(String studentId) {
    return '${widget.currentUserId}_${studentId}_$_selectedYear';
  }

  String _formatCurrency(double amount) {
    return amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
  }

  void _subscribeToDiaryDoc(
    String studentId, {
    bool preservePrefillAmount = false,
  }) {
    _diarySubscription?.cancel();
    final docId = _currentDiaryDocId(studentId);
    _diarySubscription = _firestore
        .collection('student_fees')
        .doc(docId)
        .snapshots()
        .listen((doc) {
      if (!mounted || _hasUnsavedGridEdits) return;
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final double savedMonthlyFee = (data['monthlyFee'] is num)
            ? (data['monthlyFee'] as num).toDouble()
            : 0.0;
        final normalized = _extractStatusMap(data);
        setState(() {
          if (savedMonthlyFee > 0) {
            _monthlyFeeController.text = _formatCurrency(savedMonthlyFee);
          } else if (!preservePrefillAmount) {
            _monthlyFeeController.clear();
          }
          _subjectController.text = (data['subject'] ?? '').toString();
          _monthStatuses
            ..clear()
            ..addAll(normalized);
        });
      }
    });
  }

  Future<void> _loadPrefilledStudent() async {
    final prefillId = widget.prefillStudentId?.trim() ?? '';
    if (prefillId.isEmpty || !mounted) return;

    setState(() {
      _isSearching = true;
      _foundStudent = null;
      _hasUnsavedGridEdits = false;
    });

    try {
      Map<String, dynamic>? student =
          await _reminderService.searchStudentById(prefillId);
      student ??= {
        'uid': prefillId,
        'name': (widget.prefillStudentName != null &&
                widget.prefillStudentName!.trim().isNotEmpty)
            ? widget.prefillStudentName!.trim()
            : 'Student',
      };

      if (!mounted) return;
      setState(() {
        _foundStudent = student;
        _isSearching = false;
      });

      final String resolvedId = (student['uid'] ?? prefillId).toString();
      await _fetchStudentFeeHistory(resolvedId, preservePrefillAmount: true);
      _subscribeToDiaryDoc(resolvedId, preservePrefillAmount: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _foundStudent = {
          'uid': prefillId,
          'name': (widget.prefillStudentName != null &&
                  widget.prefillStudentName!.trim().isNotEmpty)
              ? widget.prefillStudentName!.trim()
              : 'Student',
        };
        _isSearching = false;
      });
    }
  }

  Future<void> _fetchStudentFeeHistory(
    String studentId, {
    bool preservePrefillAmount = false,
  }) async {
    if (!mounted) return;
    setState(() {
      _isLoadingHistory = true;
      _hasUnsavedGridEdits = false;
    });
    try {
      final docId = _currentDiaryDocId(studentId);
      final doc = await _firestore.collection('student_fees').doc(docId).get();

      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final normalized = _extractStatusMap(data);
        final double savedMonthlyFee = (data['monthlyFee'] is num)
            ? (data['monthlyFee'] as num).toDouble()
            : 0.0;

        setState(() {
          if (savedMonthlyFee > 0) {
            _monthlyFeeController.text = _formatCurrency(savedMonthlyFee);
          } else if (!preservePrefillAmount) {
            _monthlyFeeController.clear();
          }
          _subjectController.text = (data['subject'] ?? '').toString();
          _monthStatuses
            ..clear()
            ..addAll(normalized);
        });
      } else {
        setState(() {
          _resetMonthStatuses();
          _subjectController.clear();
          if (!preservePrefillAmount) {
            _monthlyFeeController.clear();
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _searchStudent() async {
    FocusScope.of(context).unfocus();
    final searchId = _searchController.text.trim();
    if (searchId.isEmpty) return;

    _diarySubscription?.cancel();
    setState(() {
      _isSearching = true;
      _foundStudent = null;
      _hasUnsavedGridEdits = false;
    });

    try {
      final student = await _reminderService.searchStudentById(searchId);
      if (!mounted) return;

      setState(() {
        _foundStudent = student;
        _isSearching = false;
      });

      if (student != null) {
        final resolvedId = (student['uid'] ?? searchId).toString();
        await _fetchStudentFeeHistory(resolvedId);
        _subscribeToDiaryDoc(resolvedId);
      } else {
        _showErrorPopup(
          'Student Not Found',
          'No student registered with UID: $searchId\nPlease verify the ID and try again.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      _showErrorPopup(
          'Error', 'Failed to retrieve student data from the database.');
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.redAccent,
                  ),
                ),
                content: Text(message,
                    style:
                        const TextStyle(fontSize: 15, color: Colors.black87)),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _checkIfActiveFeeReminderExists(String studentId) async {
    try {
      final querySnapshot = await _firestore
          .collection('fee_reminders')
          .where('teacherId', isEqualTo: widget.currentUserId)
          .where('studentId', isEqualTo: studentId)
          .get();

      return querySnapshot.docs.any((doc) => doc.data()['isActive'] == true);
    } catch (_) {
      return true;
    }
  }

  Future<void> _showSetReminderRecommendationSheet({
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
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Color(0xFF059669),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set Monthly Fee Reminder?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Official FYBTT Automated Alerts',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0284C7),
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
                    '$studentName does not have an active Fee Reminder yet.\n\n'
                    'Setting a monthly Fee Reminder will automatically deliver official payment notices via FYBTT official and sync pending monthly dues directly to this Tuition Diary.',
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancel',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 1,
                        ),
                        icon: const Icon(Icons.alarm_add_rounded, size: 20),
                        label: const Text('Set Fee Reminder',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReminderScreen(
                                currentUserId: widget.currentUserId,
                                currentUserName: widget.currentUserName,
                                prefillStudentId: studentId,
                                prefillStudentName: studentName,
                                prefillAmount: amount > 0 ? amount : null,
                              ),
                            ),
                          );
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

  void _saveFeeRecord() async {
    FocusScope.of(context).unfocus();
    if (_foundStudent == null) return;

    setState(() => _isSaving = true);
    final String studentId =
        (_foundStudent!['uid'] ?? _searchController.text.trim()).toString();
    final String studentName = (_foundStudent!['name'] ?? 'Student').toString();
    final String docId = _currentDiaryDocId(studentId);
    final double computedTotalDue = _gridDue;
    final double computedTotalPaid = _totalPaid;
    final Map<String, String> statusesCopy = Map<String, String>.from(_monthStatuses);

    try {
      final docRef = _firestore.collection('student_fees').doc(docId);
      final monthlyRef = _firestore.collection('monthly_fee').doc(studentId);

      await _firestore.runTransaction<void>((transaction) async {
        transaction.set(
          docRef,
          {
            'teacherId': widget.currentUserId,
            'teacherName': widget.currentUserName.trim().isNotEmpty
                ? widget.currentUserName.trim()
                : 'Teacher',
            'studentId': studentId,
            'studentName': studentName,
            'subject': _subjectController.text.trim(),
            'year': _selectedYear,
            'monthlyFee': _monthlyFee,
            'monthStatuses': statusesCopy,
            'paidMonthsCount': _paidMonthsCount,
            'dueMonthsCount': _dueMonthsCount,
            'gridDueAmount': computedTotalDue,
            'totalPaid': computedTotalPaid,
            'totalCollected': computedTotalPaid,
            'totalDue': computedTotalDue,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        transaction.set(
          monthlyRef,
          {
            'studentId': studentId,
            'studentName': studentName,
            'subject': _subjectController.text.trim(),
            'teacherId': widget.currentUserId,
            'pendingAmount': computedTotalDue,
            'totalPaid': computedTotalPaid,
            'monthlyFee': _monthlyFee,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      // Keep fee_entries subcollection statuses synced with monthStatuses
      final entriesSnap = await docRef.collection('fee_entries').get();
      if (entriesSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        bool hasBatchOps = false;
        for (final entryDoc in entriesSnap.docs) {
          final entryData = entryDoc.data();
          final canonicalMonth =
              _findCanonicalMonth(entryData['month'] ?? entryData['monthName']);
          if (canonicalMonth != null) {
            final ledgerStatus = statusesCopy[canonicalMonth];
            if (ledgerStatus == 'PAID' &&
                (entryData['status'] ?? '').toString().toLowerCase() !=
                    'paid') {
              batch.update(entryDoc.reference, {
                'status': 'paid',
                'paidAt': FieldValue.serverTimestamp(),
              });
              hasBatchOps = true;
            } else if (ledgerStatus == 'DUE' &&
                (entryData['status'] ?? '').toString().toLowerCase() ==
                    'paid') {
              batch.update(entryDoc.reference, {
                'status': 'due',
                'updatedAt': FieldValue.serverTimestamp(),
              });
              hasBatchOps = true;
            }
          }
        }
        if (hasBatchOps) {
          await batch.commit();
        }
      }

      final bool hasActiveReminder =
          await _checkIfActiveFeeReminderExists(studentId);

      if (!mounted) return;
      setState(() {
        _hasUnsavedGridEdits = false;
        _isSaving = false;
      });
      SuccessToast.show(
          context, 'Fee Record Saved (Due: ₹${_formatCurrency(computedTotalDue)})');

      if (!hasActiveReminder) {
        await _showSetReminderRecommendationSheet(
          studentId: studentId,
          studentName: studentName,
          amount: _monthlyFee,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showErrorPopup('Save Failed',
          'Unable to write fee record to database. Please check connection.');
    }
  }

  Future<void> _markEntryAsPaid({
    required String studentId,
    required String entryId,
    required double entryAmount,
    required String label,
  }) async {
    if (_isSettlingPayment) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Mark Fee as Paid?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Confirm receipt of ₹${_formatCurrency(entryAmount)} for $label?\n\nThis will update the Monthly Ledger to Paid and recalculate Pending Dues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mark Paid',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isSettlingPayment = true);

    try {
      final diaryRef =
          _firestore.collection('student_fees').doc(_currentDiaryDocId(studentId));
      final entryRef = diaryRef.collection('fee_entries').doc(entryId);
      final monthlyRef = _firestore.collection('monthly_fee').doc(studentId);

      Map<String, String>? updatedStatusesResult;

      await _firestore.runTransaction((transaction) async {
        final diarySnap = await transaction.get(diaryRef);
        final entrySnap = await transaction.get(entryRef);

        if (!entrySnap.exists) return;
        final entryData = entrySnap.data() ?? {};
        if ((entryData['status'] ?? '').toString().toLowerCase() == 'paid') {
          return;
        }

        final diaryData = diarySnap.data() ?? {};
        final Map<String, String> statuses = _extractStatusMap(diaryData);

        final String? targetMonth = _findCanonicalMonth(
          entryData['month'] ?? entryData['monthName'] ?? label,
        );
        if (targetMonth != null) {
          statuses[targetMonth] = 'PAID';
        }

        final double savedMonthlyFee = (diaryData['monthlyFee'] is num)
            ? (diaryData['monthlyFee'] as num).toDouble()
            : _monthlyFee;
        final double unitFee =
            savedMonthlyFee > 0 ? savedMonthlyFee : entryAmount;

        final int newPaidCount =
            statuses.values.where((s) => s == 'PAID').length;
        final int newDueCount = statuses.values.where((s) => s == 'DUE').length;
        final double newTotalPaid = newPaidCount * unitFee;
        final double newTotalDue = newDueCount * unitFee;

        transaction.update(entryRef, {
          'status': 'paid',
          'paidAt': FieldValue.serverTimestamp(),
        });

        transaction.set(
          diaryRef,
          {
            'monthStatuses': statuses,
            'paidMonthsCount': newPaidCount,
            'dueMonthsCount': newDueCount,
            'gridDueAmount': newTotalDue,
            'totalDue': newTotalDue,
            'totalPaid': newTotalPaid,
            'totalCollected': newTotalPaid,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        transaction.set(
          monthlyRef,
          {
            'pendingAmount': newTotalDue,
            'totalPaid': newTotalPaid,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        updatedStatusesResult = statuses;
      });

      if (mounted) {
        if (updatedStatusesResult != null) {
          setState(() {
            _monthStatuses
              ..clear()
              ..addAll(updatedStatusesResult!);
            _hasUnsavedGridEdits = false;
          });
        }
        SuccessToast.show(
            context, 'Marked ₹${_formatCurrency(entryAmount)} as Paid');
      }
    } catch (_) {
      _showErrorPopup('Settlement Failed',
          'Could not update payment status. Please try again.');
    } finally {
      if (mounted) setState(() => _isSettlingPayment = false);
    }
  }

  Future<void> _showRecordManualPaymentDialog({
    required String studentId,
    required double currentDue,
  }) async {
    if (currentDue <= 0 || _isSettlingPayment) return;
    final TextEditingController payController =
        TextEditingController(text: _formatCurrency(currentDue));
    final TextEditingController noteController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Record Payment',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Pending Due: ₹${_formatCurrency(currentDue)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: payController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Amount Paid (₹)',
                prefixIcon: Icon(Icons.currency_rupee_rounded,
                    color: Colors.blue[800], size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'e.g. Cash / UPI payment',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm Paid',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    final double? paidAmount = double.tryParse(payController.text.trim());
    final String noteText = noteController.text.trim();
    payController.dispose();
    noteController.dispose();

    if (confirmed != true || !mounted) return;

    if (paidAmount == null || paidAmount <= 0) {
      _showErrorPopup(
          'Invalid Amount', 'Please enter a valid payment amount greater than 0.');
      return;
    }

    setState(() => _isSettlingPayment = true);
    try {
      final diaryRef =
          _firestore.collection('student_fees').doc(_currentDiaryDocId(studentId));
      final entryRef = diaryRef.collection('fee_entries').doc();
      final monthlyRef = _firestore.collection('monthly_fee').doc(studentId);
      Map<String, String>? updatedStatusesResult;

      await _firestore.runTransaction((transaction) async {
        final diarySnap = await transaction.get(diaryRef);
        final diaryData = diarySnap.data() ?? {};
        final Map<String, String> statuses = _extractStatusMap(diaryData);
        final double unitFee = (diaryData['monthlyFee'] is num &&
                (diaryData['monthlyFee'] as num).toDouble() > 0)
            ? (diaryData['monthlyFee'] as num).toDouble()
            : _monthlyFee;

        // Convert as many DUE months as covered by paidAmount (full months)
        if (unitFee > 0) {
          int monthsCovered = (paidAmount / unitFee).floor();
          if (paidAmount >= currentDue) {
            for (final m in _months) {
              if (statuses[m] == 'DUE') {
                statuses[m] = 'PAID';
              }
            }
          } else if (monthsCovered > 0) {
            for (final m in _months) {
              if (monthsCovered <= 0) break;
              if (statuses[m] == 'DUE') {
                statuses[m] = 'PAID';
                monthsCovered--;
              }
            }
          }
        } else if (paidAmount >= currentDue) {
          for (final m in _months) {
            if (statuses[m] == 'DUE') {
              statuses[m] = 'PAID';
            }
          }
        }

        final int newPaidCount =
            statuses.values.where((s) => s == 'PAID').length;
        final int newDueCount = statuses.values.where((s) => s == 'DUE').length;
        final double newDue = unitFee > 0
            ? newDueCount * unitFee
            : math.max(0.0, currentDue - paidAmount);
        final double newPaid =
            unitFee > 0 ? newPaidCount * unitFee : (_totalPaid + paidAmount);

        transaction.set(
          diaryRef,
          {
            'monthStatuses': statuses,
            'paidMonthsCount': newPaidCount,
            'dueMonthsCount': newDueCount,
            'gridDueAmount': newDue,
            'totalDue': newDue,
            'totalPaid': newPaid,
            'totalCollected': newPaid,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        transaction.set(entryRef, {
          'entryId': entryRef.id,
          'amount': paidAmount,
          'status': 'paid',
          'source': 'manual_payment',
          'month': noteText.isNotEmpty ? noteText : 'Manual Payment',
          'monthName': noteText.isNotEmpty ? noteText : 'Manual Payment',
          'createdAt': FieldValue.serverTimestamp(),
          'paidAt': FieldValue.serverTimestamp(),
        });

        transaction.set(
          monthlyRef,
          {
            'pendingAmount': newDue,
            'totalPaid': newPaid,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        updatedStatusesResult = statuses;
      });

      if (mounted) {
        if (updatedStatusesResult != null) {
          setState(() {
            _monthStatuses
              ..clear()
              ..addAll(updatedStatusesResult!);
            _hasUnsavedGridEdits = false;
          });
        }
        SuccessToast.show(
            context, 'Payment of ₹${_formatCurrency(paidAmount)} Recorded');
      }
    } catch (_) {
      _showErrorPopup('Error', 'Could not record payment. Please try again.');
    } finally {
      if (mounted) setState(() => _isSettlingPayment = false);
    }
  }

  Widget _buildStudentAvatar(String studentId, String studentName) {
    final String? imageUrl = _foundStudent?['profileImageUrl'] ??
        _foundStudent?['profilePic'] ??
        _foundStudent?['photoUrl'];

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.network(
          imageUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatar(studentName),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('students').doc(studentId).get(),
      builder: (context, snapshot) {
        String? remoteImg;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          remoteImg = data?['profileImageUrl'] ??
              data?['profilePic'] ??
              data?['imageUrl'];
        }

        if (remoteImg != null && remoteImg.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.network(
              remoteImg,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackAvatar(studentName),
            ),
          );
        }

        return _fallbackAvatar(studentName);
      },
    );
  }

  Widget _fallbackAvatar(String name) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.indigo.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'S',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildStatusChip(
      String month, String status, String label, Color activeBgColor) {
    final bool isSelected = _monthStatuses[month] == status;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _hasUnsavedGridEdits = true;
            _monthStatuses[month] = status;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeBgColor : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeBgColor : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthCard(String month) {
    final status = _monthStatuses[month] ?? 'NOT_ENROLLED';

    Color monthBadgeColor = const Color(0xFF64748B);
    if (status == 'PAID') monthBadgeColor = const Color(0xFF10B981);
    if (status == 'DUE') monthBadgeColor = const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                month,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: monthBadgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status == 'PAID'
                      ? 'PAID'
                      : (status == 'DUE' ? 'DUE' : 'NOT ENROLLED'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: monthBadgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatusChip(month, 'PAID', 'Paid', const Color(0xFF10B981)),
              _buildStatusChip(month, 'DUE', 'Due', const Color(0xFFEF4444)),
              _buildStatusChip(
                  month, 'NOT_ENROLLED', 'Not Enrolled', const Color(0xFF64748B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeeEntriesLedger(String studentId) {
    final diaryDocId = _currentDiaryDocId(studentId);
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('student_fees')
          .doc(diaryDocId)
          .collection('fee_entries')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final docs = [...(snapshot.data?.docs ?? [])];
        docs.sort((a, b) {
          final aData = (a.data() as Map<String, dynamic>?) ?? {};
          final bData = (b.data() as Map<String, dynamic>?) ?? {};
          final aStatus = (aData['status'] ?? '').toString().toLowerCase();
          final bStatus = (bData['status'] ?? '').toString().toLowerCase();
          final aUnpaid = (aStatus == 'pending' || aStatus == 'due') ? 1 : 0;
          final bUnpaid = (bStatus == 'pending' || bStatus == 'due') ? 1 : 0;
          if (aUnpaid != bUnpaid) return bUnpaid.compareTo(aUnpaid);
          final aTs = (aData['createdAt'] ?? aData['paidAt']) as Timestamp?;
          final bTs = (bData['createdAt'] ?? bData['paidAt']) as Timestamp?;
          return (bTs?.millisecondsSinceEpoch ?? 0)
              .compareTo(aTs?.millisecondsSinceEpoch ?? 0);
        });

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded,
                    color: Colors.grey.shade400, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No automated or manual fee entries yet. When scheduled reminders fire, pending entries appear here.',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                        height: 1.35),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = (doc.data() as Map<String, dynamic>?) ?? {};
            final double amount = (data['amount'] is num)
                ? (data['amount'] as num).toDouble()
                : double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
            final String status =
                (data['status'] ?? 'due').toString().toLowerCase();
            final bool isPaid = status == 'paid';
            final String monthLabel =
                (data['monthName'] ?? data['month'] ?? 'Monthly Fee')
                    .toString();
            final String dueDateText =
                (data['dueDateText'] ?? data['dueDate'] ?? '').toString();
            final Timestamp? ts =
                (isPaid ? (data['paidAt'] ?? data['createdAt']) : data['createdAt'])
                    as Timestamp?;
            String dateLabel = dueDateText;
            if (ts != null) {
              final dt =
                  ts.toDate().toUtc().add(const Duration(hours: 5, minutes: 30));
              final d = dt.day.toString().padLeft(2, '0');
              final m = dt.month.toString().padLeft(2, '0');
              dateLabel = '$d/$m/${dt.year}';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPaid
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFFECACA),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPaid
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      color: isPaid
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '₹${_formatCurrency(amount)}',
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isPaid ? 'PAID' : 'DUE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isPaid
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          dateLabel.isNotEmpty
                              ? '$monthLabel • $dateLabel'
                              : monthLabel,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isPaid)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _isSettlingPayment
                          ? null
                          : () => _markEntryAsPaid(
                                studentId: studentId,
                                entryId: doc.id,
                                entryAmount: amount,
                                label: monthLabel,
                              ),
                      child: const Text(
                        'Mark Paid',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String activeStudentId = _foundStudent != null
        ? (_foundStudent!['uid'] ?? _searchController.text.trim()).toString()
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'My Diary',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 19),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
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
                    'Select Student',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B1B1B)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Enter Student User ID',
                            hintStyle: TextStyle(
                                color: Colors.grey[400], fontSize: 14),
                            prefixIcon: Icon(Icons.tag_rounded,
                                color: Colors.blue[800], size: 22),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.blue.shade400, width: 1.5),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onSubmitted: (_) => _searchStudent(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: _isSearching ? null : _searchStudent,
                        child: _isSearching
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Icon(Icons.search_rounded, size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_foundStudent != null) ...[
              const SizedBox(height: 20),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _buildStudentAvatar(
                                activeStudentId,
                                (_foundStudent!['name'] ?? 'Student')
                                    .toString(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (_foundStudent!['name'] ?? 'Student')
                                          .toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      activeStudentId,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey[600],
                                        fontFamily: 'monospace',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedYear,
                              icon: Icon(Icons.arrow_drop_down,
                                  color: Colors.blue[800]),
                              items: _availableYears.map((year) {
                                return DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(
                                    year.toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[800],
                                      fontSize: 13.5,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (year) {
                                if (year != null) {
                                  setState(() => _selectedYear = year);
                                  _fetchStudentFeeHistory(activeStudentId);
                                  _subscribeToDiaryDoc(activeStudentId);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14.0),
                      child: Divider(
                          height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    ),
                    TextField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        labelText: 'Subject Taught',
                        hintText: 'e.g. Mathematics, Science, English',
                        prefixIcon: Icon(Icons.menu_book_rounded,
                            color: Colors.blue[800], size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: Colors.blue.shade400, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _monthlyFeeController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Monthly Tuition Fee (₹)',
                        hintText: 'e.g. 1000',
                        prefixIcon: Icon(Icons.currency_rupee_rounded,
                            color: Colors.blue[800]),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: Colors.blue.shade400, width: 1.5),
                        ),
                      ),
                      onChanged: (_) => setState(() {
                        _hasUnsavedGridEdits = true;
                      }),
                    ),
                    const SizedBox(height: 14),
                    StreamBuilder<DocumentSnapshot>(
                      stream: _firestore
                          .collection('student_fees')
                          .doc(_currentDiaryDocId(activeStudentId))
                          .snapshots(),
                      builder: (context, snapshot) {
                        Map<String, String> effectiveStatuses = _monthStatuses;
                        double effectiveFee = _monthlyFee;

                        if (!_hasUnsavedGridEdits &&
                            snapshot.hasData &&
                            snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          if (data != null) {
                            effectiveStatuses = _extractStatusMap(data);
                            final double serverFee =
                                (data['monthlyFee'] is num)
                                    ? (data['monthlyFee'] as num).toDouble()
                                    : 0.0;
                            if (serverFee > 0) {
                              effectiveFee = serverFee;
                            }
                          }
                        }

                        final int effectivePaidCount = effectiveStatuses.values
                            .where((s) => s == 'PAID')
                            .length;
                        final int effectiveDueCount = effectiveStatuses.values
                            .where((s) => s == 'DUE')
                            .length;
                        final double displayPaid =
                            effectivePaidCount * effectiveFee;
                        final double displayDue =
                            effectiveDueCount * effectiveFee;

                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Total Collected',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${_formatCurrency(displayPaid)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                        Text(
                                          'Paid ($effectivePaidCount Mo)',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                      width: 1,
                                      height: 40,
                                      color: const Color(0xFFCBD5E1)),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Total Outstanding Due',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '₹${_formatCurrency(displayDue)}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFEF4444),
                                            ),
                                          ),
                                          Text(
                                            'Due ($effectiveDueCount Mo)',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (displayDue > 0 &&
                                snapshot.hasData &&
                                snapshot.data!.exists) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF059669),
                                    side: const BorderSide(
                                        color: Color(0xFF10B981)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 11),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.payments_outlined,
                                      size: 18),
                                  label: const Text(
                                    'Record Payment / Settle Due',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  onPressed: _isSettlingPayment
                                      ? null
                                      : () => _showRecordManualPaymentDialog(
                                            studentId: activeStudentId,
                                            currentDue: displayDue,
                                          ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Automated & Payment Ledger',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),
              _buildFeeEntriesLedger(activeStudentId),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_selectedYear Academic Months',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (_isLoadingHistory)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ..._months.map((m) => _buildMonthCard(m)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  onPressed: _isSaving ? null : _saveFeeRecord,
                  icon: _isSaving
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'SAVE FEE RECORD',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 0.5),
                        ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DiaryHistoryScreen(
                      currentUserId: widget.currentUserId,
                      currentUserName: widget.currentUserName,
                    ),
                  ),
                );
              },
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
                      child: const Icon(Icons.auto_stories_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Diary History',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Search, filter and update entries globally',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white, size: 18),
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