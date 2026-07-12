import 'package:flutter/material.dart';
import '../../models/diary_model.dart';
import '../../models/attendance_model.dart';
import '../../services/diary_service.dart';
import '../../services/attendance_service.dart';
import '../../services/reminder_service.dart';
import '../../widgets/success_toast.dart';

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
  final DiaryService _diaryService = DiaryService();
  final AttendanceService _attendanceService = AttendanceService();
  final ReminderService _reminderService = ReminderService();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _homeworkController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  Map<String, dynamic>? _foundStudent;
  bool _isSearching = false;
  bool _isSaving = false;

  DateTime _selectedDate = DateTime.now();
  String _attendanceStatus = 'Present';

  final List<String> _attendanceStates = ['Present', 'Absent', 'Late', 'Holiday'];
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  void _searchStudent() async {
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
      if (student == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student not found! Please check the ID and try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _saveDiaryAndAttendance() async {
    if (_foundStudent == null || _subjectController.text.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final String diaryId = DateTime.now().millisecondsSinceEpoch.toString();
      final String currentMonth = _months[_selectedDate.month - 1];

      final diary = DiaryModel(
        diaryId: diaryId,
        studentName: _foundStudent!['name'] ?? 'Student',
        studentId: _foundStudent!['uid'] ?? '',
        teacherId: widget.currentUserId,
        month: currentMonth,
        date: _selectedDate,
        subject: _subjectController.text.trim(),
        topicCovered: _topicController.text.trim(),
        homework: _homeworkController.text.trim(),
        privateNote: _noteController.text.trim(),
      );

      final attendance = AttendanceModel(
        attendanceId: diaryId,
        studentId: _foundStudent!['uid'] ?? '',
        studentName: _foundStudent!['name'] ?? 'Student',
        teacherId: widget.currentUserId,
        date: _selectedDate,
        status: _attendanceStatus,
      );

      await _diaryService.saveDiaryEntry(diary);
      await _attendanceService.saveAttendance(attendance);

      if (mounted) {
        SuccessToast.show(context, 'Diary Saved Successfully');
        setState(() {
          _foundStudent = null;
          _searchController.clear();
          _subjectController.clear();
          _topicController.clear();
          _homeworkController.clear();
          _noteController.clear();
          _attendanceStatus = 'Present';
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
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
            // সার্চ কার্ড কন্টেইনার
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
            
            // ডায়নামিক ফর্ম সেকশন (স্টুডেন্ট ডাটা লোড হলে অ্যানিমেটেড উপায়ে আসবে)
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
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blue[50],
                                    radius: 18,
                                    child: Icon(Icons.person_rounded, color: Colors.blue[800], size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${_foundStudent!['name'] ?? 'No Name'}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B1B1B)),
                                  ),
                                ],
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
                                      Text(
                                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                        style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          ),
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
                                    child: Center(
                                      child: Text(
                                        state,
                                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          ),
                          TextField(
                            controller: _subjectController,
                            decoration: InputDecoration(
                              labelText: 'Subject',
                              prefixIcon: Icon(Icons.book_outlined, color: Colors.blue[800], size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
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
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
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
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 18),
                          // প্রাইভেট নোট সেকশন (সিকিউর শেডেড ব্যাকগ্রাউন্ড সহ)
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
                                labelText: 'Private Note (Only Visible to You)',
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
                        onPressed: _isSaving || _subjectController.text.isEmpty ? null : _saveDiaryAndAttendance,
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
          ],
        ),
      ),
    );
  }
}
