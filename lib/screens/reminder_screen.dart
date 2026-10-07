import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/reminder_model.dart';
import '../../services/reminder_service.dart';
import '../../widgets/success_toast.dart';
import 'active_reminders_screen.dart';

class ReminderScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const ReminderScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
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
  late String _selectedMonth;
  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 5));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 16, minute: 0);

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonth = _months[DateTime.now().month - 1];
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    super.dispose();
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
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.redAccent),
                ),
                content: Text(message, style: const TextStyle(fontSize: 15, color: Colors.black87)),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

      if (student == null) {
        _showErrorPopup(
          'Student Not Found',
          'No student registered with UID: $searchId\nPlease make sure the UID is correct and active.',
        );
      }
    } catch (e) {
      setState(() => _isSearching = false);
      _showErrorPopup('Query Error', 'Something went wrong while searching the database.');
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
      barrierLabel: '',
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
                  'Set Reminder Time',
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
    );
  }

  void _sendReminder() async {
    FocusScope.of(context).unfocus();
    if (_foundStudent == null || _amountController.text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final double amount = double.parse(_amountController.text.trim());
      final String reminderId = DateTime.now().millisecondsSinceEpoch.toString();

      final DateTime scheduledTime = DateTime(
        _selectedDueDate.year,
        _selectedDueDate.month,
        _selectedDueDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final reminder = ReminderModel(
        reminderId: reminderId,
        studentName: _foundStudent!['name'] ?? 'Student',
        studentId: _foundStudent!['uid'] ?? _searchController.text.trim(),
        teacherId: widget.currentUserId,
        teacherName: widget.currentUserName,
        amount: amount,
        month: _selectedMonth,
        dueDate: _selectedDueDate,
        reminderTime: scheduledTime,
        status: 'sent',
      );

      await _reminderService.sendPaymentReminder(reminder);

      if (mounted) {
        SuccessToast.show(context, 'Reminder Scheduled Successfully');
        setState(() {
          _foundStudent = null;
          _searchController.clear();
          _amountController.clear();
          _isSending = false;
        });
      }
    } catch (e) {
      setState(() => _isSending = false);
      _showErrorPopup('Failed', 'Could not transmit the reminder request. Please try again.');
    }
  }

  String _formatHourMinute(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isAm = _selectedTime.period == DayPeriod.am;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Fee Reminder', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 19)),
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
                  const Text('Search Student', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B1B1B))),
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
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(14)),
                              child: Icon(Icons.person_rounded, color: Colors.blue[800], size: 26),
                            ),
                            title: Text(_foundStudent!['name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1B1B1B))),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(_foundStudent!['uid'] ?? 'No ID', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
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
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
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
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
                            ),
                            items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 14)))).toList(),
                            onChanged: (val) => setState(() => _selectedMonth = val!),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDueDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 90)),
                                    );
                                    if (picked != null) setState(() => _selectedDueDate = picked);
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
                                        Text('${_selectedDueDate.day}/${_selectedDueDate.month}/${_selectedDueDate.year}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                                      labelText: 'Send Time',
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Message Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B1B1B))),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        "Hello ${_foundStudent!['name'] ?? 'Student'},\n\n"
                        "This is a friendly reminder from ${widget.currentUserName}.\n"
                        "Your tuition fee for $_selectedMonth is now due.\n\n"
                        "Amount: ₹${_amountController.text.isEmpty ? '0' : _amountController.text}\n"
                        "Due Date: ${_selectedDueDate.day}/${_selectedDueDate.month}/${_selectedDueDate.year}\n"
                        "Scheduled Time: ${_formatHourMinute(_selectedTime)} ${isAm ? 'AM' : 'PM'}\n\n"
                        "Please complete the payment at your earliest convenience.\n"
                        "Thank you.",
                        style: TextStyle(fontSize: 14, color: Colors.blueGrey[800], height: 1.4, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 28),
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
                        onPressed: _isSending || _amountController.text.isEmpty ? null : _sendReminder,
                        icon: _isSending ? const SizedBox.shrink() : const Icon(Icons.send_rounded, size: 20),
                        label: _isSending
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('SCHEDULE REMINDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
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
                  MaterialPageRoute(
                    builder: (context) => ActiveRemindersScreen(teacherId: widget.currentUserId),
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
                    )
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
                                .collection('payment_reminders')
                                .where('teacherId', isEqualTo: widget.currentUserId)
                                .where('status', isEqualTo: 'sent')
                                .snapshots(),
                            builder: (context, snapshot) {
                              int activeCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                              return Text(
                                activeCount > 0
                                    ? 'You have $activeCount pending active reminders'
                                    : 'View and manage sent reminders',
                                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w500),
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