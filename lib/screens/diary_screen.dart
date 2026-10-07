import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/reminder_service.dart';
import '../../widgets/success_toast.dart';
import 'diary_history_screen.dart';

class DiaryScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const DiaryScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
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

  int _selectedYear = 2026;
  final List<int> _availableYears = [2024, 2025, 2026, 2027, 2028, 2029];

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  final Map<String, String> _monthStatuses = {};

  @override
  void initState() {
    super.initState();
    _resetMonthStatuses();
  }

  void _resetMonthStatuses() {
    for (var month in _months) {
      _monthStatuses[month] = 'NOT_ENROLLED';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _subjectController.dispose();
    _monthlyFeeController.dispose();
    super.dispose();
  }

  double get _monthlyFee => double.tryParse(_monthlyFeeController.text.trim()) ?? 0.0;

  int get _paidMonthsCount => _monthStatuses.values.where((status) => status == 'PAID').length;
  int get _dueMonthsCount => _monthStatuses.values.where((status) => status == 'DUE').length;

  double get _totalPaid => _paidMonthsCount * _monthlyFee;
  double get _totalDue => _dueMonthsCount * _monthlyFee;

  void _fetchStudentFeeHistory(String studentId) async {
    setState(() => _isLoadingHistory = true);
    try {
      final docId = '${widget.currentUserId}_${studentId}_$_selectedYear';
      final doc = await _firestore.collection('student_fees').doc(docId).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final savedStatuses = data['monthStatuses'] as Map<String, dynamic>?;

        setState(() {
          _monthlyFeeController.text = (data['monthlyFee'] != null)
              ? data['monthlyFee'].toString()
              : '';
          _subjectController.text = (data['subject'] ?? '').toString();
          if (savedStatuses != null) {
            for (var month in _months) {
              _monthStatuses[month] = savedStatuses[month]?.toString() ?? 'NOT_ENROLLED';
            }
          }
        });
      } else {
        setState(() {
          _resetMonthStatuses();
          _subjectController.clear();
        });
      }
    } catch (e) {
      debugPrint("Error fetching student fee record: $e");
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _searchStudent() async {
    FocusScope.of(context).unfocus();
    final searchId = _searchController.text.trim();
    if (searchId.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundStudent = null;
    });

    try {
      final student = await _reminderService.searchStudentById(searchId);
      setState(() {
        _foundStudent = student;
        _isSearching = false;
      });

      if (student != null) {
        _fetchStudentFeeHistory(student['uid'] ?? searchId);
      } else {
        _showErrorPopup('Student Not Found', 'No student registered with UID: $searchId\nPlease verify the ID and try again.');
      }
    } catch (e) {
      setState(() => _isSearching = false);
      _showErrorPopup('Error', 'Failed to retrieve student data from the database.');
    }
  }

  void _showErrorPopup(String title, String message) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
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
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.redAccent)),
                content: Text(message, style: const TextStyle(fontSize: 15, color: Colors.black87)),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void _saveFeeRecord() async {
    FocusScope.of(context).unfocus();
    if (_foundStudent == null) return;

    setState(() => _isSaving = true);
    final studentId = _foundStudent!['uid'] ?? _searchController.text.trim();
    final docId = '${widget.currentUserId}_${studentId}_$_selectedYear';

    try {
      await _firestore.collection('student_fees').doc(docId).set({
        'teacherId': widget.currentUserId,
        'teacherName': widget.currentUserName,
        'studentId': studentId,
        'studentName': _foundStudent!['name'] ?? 'Student',
        'subject': _subjectController.text.trim(),
        'year': _selectedYear,
        'monthlyFee': _monthlyFee,
        'monthStatuses': _monthStatuses,
        'paidMonthsCount': _paidMonthsCount,
        'dueMonthsCount': _dueMonthsCount,
        'totalPaid': _totalPaid,
        'totalDue': _totalDue,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('monthly_fee').doc(studentId).set({
        'studentId': studentId,
        'studentName': _foundStudent!['name'] ?? 'Student',
        'subject': _subjectController.text.trim(),
        'teacherId': widget.currentUserId,
        'pendingAmount': _totalDue,
        'totalPaid': _totalPaid,
        'monthlyFee': _monthlyFee,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        SuccessToast.show(context, 'Fee Record Saved Successfully');
        setState(() {
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorPopup('Save Failed', 'Unable to write fee record to database. Please check connection.');
    }
  }

  Widget _buildStatusChip(String month, String status, String label, Color activeBgColor) {
    final bool isSelected = _monthStatuses[month] == status;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
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
              _buildStatusChip(month, 'NOT_ENROLLED', 'Not Enrolled', const Color(0xFF64748B)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('My Diary', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 19)),
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Student', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B1B1B))),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
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
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6))],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _foundStudent!['name'] ?? 'Student',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _foundStudent!['uid'] ?? '',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedYear,
                              icon: Icon(Icons.arrow_drop_down, color: Colors.blue[800]),
                              items: _availableYears.map((year) {
                                return DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(
                                    year.toString(),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800], fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (year) {
                                if (year != null) {
                                  setState(() => _selectedYear = year);
                                  _fetchStudentFeeHistory(_foundStudent!['uid'] ?? _searchController.text.trim());
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 14.0), child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9))),
                    TextField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        labelText: 'Subject Taught',
                        hintText: 'e.g. Mathematics, Science, English',
                        prefixIcon: Icon(Icons.menu_book_rounded, color: Colors.blue[800], size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _monthlyFeeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      decoration: InputDecoration(
                        labelText: 'Monthly Tuition Fee (₹)',
                        hintText: 'e.g. 1000',
                        prefixIcon: Icon(Icons.currency_rupee_rounded, color: Colors.blue[800]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Paid', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('₹${_totalPaid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                                Text('($_paidMonthsCount Months)', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 40, color: const Color(0xFFCBD5E1)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pending Due', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('₹${_totalDue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                                  Text('($_dueMonthsCount Months)', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_selectedYear Academic Months',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  if (_isLoadingHistory)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  onPressed: _isSaving ? null : _saveFeeRecord,
                  icon: _isSaving ? const SizedBox.shrink() : const Icon(Icons.check_circle_outline, size: 20),
                  label: _isSaving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('SAVE FEE RECORD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
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
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.25), blurRadius: 15, offset: const Offset(0, 6))],
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Diary History', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Search, filter and update entries globally', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
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