import 'dart:ui'; // BackdropFilter এর জন্য প্রয়োজন
import 'package:flutter/material.dart';
import '../../models/reminder_model.dart';
import '../../services/reminder_service.dart';
import '../../widgets/success_toast.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  Map<String, dynamic>? _foundStudent;
  bool _isSearching = false;
  bool _isSending = false;
  late String _selectedMonth; // ডাইনামিক কারেন্ট মান্থের জন্য late ব্যবহার করা হয়েছে
  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 5));

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    // স্বয়ংক্রিয়ভাবে বর্তমান মাসের নাম সিলেক্ট করার লজিক
    _selectedMonth = _months[DateTime.now().month - 1];
  }

  // স্টুডেন্ট না পাওয়া গেলে সুন্দর অ্যানিমেটেড ব্লার পপআপ
  void _showErrorPopup(String title, String message) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, a1, a2) => const SizedBox(),
      transitionBuilder: (context, anim, a2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // প্রফেশনাল ব্লার এফেক্ট
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        // স্ন্যাকবারের পরিবর্তে নতুন অ্যানিমেটেড ব্লার পপআপ শো করা হবে
        _showErrorPopup('Student Not Found', 'Please check the Student User ID and try again.');
      }
    } catch (e) {
      setState(() => _isSearching = false);
      _showErrorPopup('Error', 'Something went wrong while searching.');
    }
  }

  void _sendReminder() async {
    if (_foundStudent == null || _amountController.text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final double amount = double.parse(_amountController.text.trim());
      final String reminderId = DateTime.now().millisecondsSinceEpoch.toString();

      final reminder = ReminderModel(
        reminderId: reminderId,
        studentName: _foundStudent!['name'] ?? 'Student',
        studentId: _foundStudent!['uid'] ?? '',
        teacherId: widget.currentUserId,
        teacherName: widget.currentUserName,
        amount: amount,
        month: _selectedMonth,
        dueDate: _selectedDueDate,
        reminderTime: DateTime.now(),
        status: 'sent',
      );

      await _reminderService.sendPaymentReminder(reminder);

      if (mounted) {
        SuccessToast.show(context, 'Reminder Sent Successfully');
        setState(() {
          _foundStudent = null;
          _searchController.clear();
          _amountController.clear();
          _isSending = false;
        });
      }
    } catch (e) {
      setState(() => _isSending = false);
      _showErrorPopup('Failed', 'Could not send the reminder. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Free Reminder', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Search Student', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B1B1B))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Enter Student User ID',
                            prefixIcon: const Icon(Icons.tag),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSearching ? null : _searchStudent,
                        child: _isSearching 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.search),
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
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[50],
                        radius: 24,
                        child: Icon(Icons.person, color: Colors.blue[800]),
                      ),
                      title: Text(_foundStudent!['name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(_foundStudent!['email'] ?? 'No Email', style: const TextStyle(fontSize: 13)),
                    ),
                    const Divider(height: 24),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedMonth,
                            decoration: InputDecoration(
                              labelText: 'Month',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                            onChanged: (val) => setState(() => _selectedMonth = val!),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.between,
                                children: [
                                  Text('${_selectedDueDate.day}/${_selectedDueDate.month}/${_selectedDueDate.year}', style: const TextStyle(fontSize: 14)),
                                  const Icon(Icons.calendar_today, size: 18),
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
              const SizedBox(height: 20),
              const Text('Message Preview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B1B1B))),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Hello ${_foundStudent!['name'] ?? 'Student'},\n\n"
                  "This is a friendly reminder from ${widget.currentUserName}.\n"
                  "Your tuition fee for $_selectedMonth is now due.\n\n"
                  "Amount: ₹${_amountController.text.isEmpty ? '0' : _amountController.text}\n"
                  "Due Date: ${_selectedDueDate.day}/${_selectedDueDate.month}/${_selectedDueDate.year}\n\n"
                  "Please complete the payment at your earliest convenience.\n"
                  "Thank you.",
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  onPressed: _isSending || _amountController.text.isEmpty ? null : _sendReminder,
                  icon: const Icon(Icons.send_rounded),
                  label: _isSending 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('SEND REMINDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
