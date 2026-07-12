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
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _homeworkController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  Map<String, dynamic>? _foundStudent;
  bool _isSearching = false;
  bool _isSaving = false;

  DateTime _selectedDate = DateTime.now();
  String _attendanceStatus = 'Present';
  String _feeStatus = 'NO';

  double _monthlyFee = 0.0;
  double _previousPending = 0.0;
  double _paidAmount = 0.0;
  double _remainingPending = 0.0;

  final List<String> _attendanceStates = ['Present', 'Absent', 'Late', 'Holiday'];
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  late String _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _months[DateTime.now().month - 1];
  }

  // ফায়ারস্টোর থেকে লাইভ ফি ব্যালেন্স লোড করার মেথড
  void _fetchStudentFeeStructure(String studentId) async {
    try {
      // monthly_fee কালেকশন থেকে স্টুডেন্টের কারেন্ট ব্যালেন্স চেক
      final feeDoc = await _firestore.collection('monthly_fee').doc(studentId).get();
      if (feeDoc.exists && feeDoc.data() != null) {
        final data = feeDoc.data()!;
        setState(() {
          _monthlyFee = (data['monthlyFee'] ?? 1000.0).toDouble();
          _previousPending = (data['pendingAmount'] ?? 0.0).toDouble();
          _calculateBalances();
        });
      } else {
        // নতুন স্টুডেন্ট হলে ডিফল্ট সেটআপ
        setState(() {
          _monthlyFee = 1000.0;
          _previousPending = 0.0;
          _calculateBalances();
        });
      }
    } catch (e) {
      debugPrint("Error fetching fee structure: $e");
    }
  }

  void _calculateBalances() {
    setState(() {
      if (_feeStatus == 'YES') {
        _paidAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
        _remainingPending = (_previousPending + _monthlyFee) - _paidAmount;
      } else {
        _paidAmount = 0.0;
        _remainingPending = _previousPending + _monthlyFee;
      }
    });
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
        _fetchStudentFeeStructure(searchId);
      } else {
        _showErrorPopup('Student Not Found', 'Please check the Student User ID and try again.');
      }
    } catch (e) {
      setState(() => _isSearching = false);
      _showErrorPopup('Error', 'Something went wrong while searching.');
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

  // ফায়ারস্টোর প্রোডাকশন রাইট ইঞ্জিন (ব্যাচ ট্রানজেকশন)
  void _saveDiaryToFirebase() async {
    if (_foundStudent == null || _subjectController.text.isEmpty) return;

    setState(() => _isSaving = true);
    final studentId = _foundStudent!['uid'] ?? '';
    final String entryId = _firestore.collection('diary').doc().id;

    final batch = _firestore.batch();

    try {
      // ১. মূল ডায়েরি কালেকশনে ডেটা রাইট
      final diaryRef = _firestore.collection('diary').doc(entryId);
      batch.set(diaryRef, {
        'diaryId': entryId,
        'studentId': studentId,
        'studentName': _foundStudent!['name'] ?? 'Student',
        'teacherId': widget.currentUserId,
        'teacherName': widget.currentUserName,
        'date': Timestamp.fromDate(_selectedDate),
        'attendanceStatus': _attendanceStatus,
        'subject': _subjectController.text.trim(),
        'topicCovered': _topicController.text.trim(),
        'homework': _homeworkController.text.trim(),
        'month': _selectedMonth,
        'feeStatus': _feeStatus,
        // বাগ ১৩ সিকিউরিটি ফিক্স: প্রাইভেট নোট আলাদা প্রটেকশন ব্লকে রাখা হলো
        'privateNote': _noteController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ২. monthly_fee লেজার রিয়াল-টাইম ব্যালেন্স আপডেট
      final feeRef = _firestore.collection('monthly_fee').doc(studentId);
      batch.set(feeRef, {
        'studentId': studentId,
        'studentName': _foundStudent!['name'] ?? 'Student',
        'monthlyFee': _monthlyFee,
        'pendingAmount': _remainingPending,
        'totalPaid': FieldValue.increment(_paidAmount),
        'lastUpdated': FieldValue.serverTimestamp(),
        // ১২ মাসের ট্র্যাকিং লেজার রিয়াল-টাইম মেপিং
        'feeStatus12Months.$_selectedMonth': _feeStatus,
      }, SetOptions(merge: true));

      // ৩. বাগ ৮ ফিক্স: ফি রিসিভড হলে পেমেন্ট হিস্ট্রি জেনারেট
      if (_feeStatus == 'YES' && _paidAmount > 0) {
        final paymentId = _firestore.collection('payment_history').doc().id;
        final paymentRef = _firestore.collection('payment_history').doc(paymentId);
        batch.set(paymentRef, {
          'paymentId': paymentId,
          'studentId': studentId,
          'studentName': _foundStudent!['name'] ?? 'Student',
          'teacherId': widget.currentUserId,
          'teacherName': widget.currentUserName,
          'amount': _paidAmount,
          'month': _selectedMonth,
          'date': Timestamp.fromDate(_selectedDate),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // ব্যাচ ট্রানজেকশন কমিট
      await batch.commit();

      if (mounted) {
        SuccessToast.show(context, 'Diary & Fee Saved Successfully');
        setState(() {
          _foundStudent = null;
          _searchController.clear();
          _subjectController.clear();
          _topicController.clear();
          _homeworkController.clear();
          _noteController.clear();
          _amountController.clear();
          _attendanceStatus = 'Present';
          _feeStatus = 'NO';
          _paidAmount = 0.0;
          _remainingPending = 0.0;
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorPopup('Failed', 'Database Write Failed. Try Again.');
    }
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_foundStudent!['name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1B1B1B))),
                                    const SizedBox(height: 3),
                                    Text(_foundStudent!['uid'] ?? 'No ID', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now().add(const Duration(days: 30)),
                                  );
                                  if (picked != null) setState(() => _selectedDate = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 14, color: Colors.blue[800]),
                                      const SizedBox(width: 6),
                                      Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}', style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9))),
                          const Text('Attendance Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: _attendanceStates.map((state) {
                              final isSelected = _attendanceStatus == state;
                              Color btnColor = const Color(0xFFF1F5F9);
                              Color textColor = Colors.black87;
                              if (isSelected) {
                                if (state == 'Present') { btnColor = const Color(0xFF10B981); textColor = Colors.white; }
                                if (state == 'Absent') { btnColor = const Color(0xFFEF4444); textColor = Colors.white; }
                                if (state == 'Late') { btnColor = const Color(0xFFF59E0B); textColor = Colors.white; }
                                if (state == 'Holiday') { btnColor = const Color(0xFF3B82F6); textColor = Colors.white; }
                              }
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _attendanceStatus = state),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: btnColor,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: isSelected ? [BoxShadow(color: btnColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
                                    ),
                                    child: Center(child: Text(state, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13))),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9))),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedMonth,
                                  decoration: InputDecoration(labelText: 'Select Month', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                                  items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedMonth = val!;
                                      _calculateBalances();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _feeStatus,
                                  decoration: InputDecoration(labelText: 'Fee Received?', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                                  items: ['YES', 'NO'].map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _feeStatus = val!;
                                      _calculateBalances();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_feeStatus == 'YES') ...[
                            const SizedBox(height: 18),
                            TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                labelText: 'Enter Received Amount (₹)',
                                prefixIcon: Icon(Icons.currency_rupee_rounded, color: Colors.blue[800]),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onChanged: (_) => _calculateBalances(),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Paid: ₹${_paidAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                Text('Pending Due: ₹${_remainingPending.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              ],
                            ),
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9))),
                          TextField(
                            controller: _subjectController,
                            decoration: InputDecoration(
                              labelText: 'Subject',
                              prefixIcon: Icon(Icons.book_outlined, color: Colors.blue[800], size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _topicController,
                            decoration: InputDecoration(
                              labelText: 'Topic Covered',
                              prefixIcon: Icon(Icons.assignment_outlined, color: Colors.blue[800], size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _homeworkController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Homework Assigned',
                              prefixIcon: Icon(Icons.edit_note_outlined, color: Colors.blue[800], size: 22),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: TextField(
                              controller: _noteController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Private Note (Only Visible to Teacher)',
                                labelStyle: const TextStyle(fontSize: 13),
                                prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.amber[700], size: 20),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
                        onPressed: _isSaving || _subjectController.text.isEmpty ? null : _saveDiaryToFirebase,
                        icon: _isSaving ? const SizedBox.shrink() : const Icon(Icons.save_rounded, size: 20),
                        label: _isSaving 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('SAVE DIARY ENTRY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DiaryHistoryScreen()),
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