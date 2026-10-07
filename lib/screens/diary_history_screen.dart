import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/success_toast.dart';

class DiaryHistoryScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const DiaryHistoryScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<DiaryHistoryScreen> createState() => _DiaryHistoryScreenState();
}

class _DiaryHistoryScreenState extends State<DiaryHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'All';
  String _searchQuery = '';
  final List<String> _filters = ['All', 'Pending Dues', 'Fully Paid'];

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEditStudentFeeSheet(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String docId = doc.id;
    final String studentId = data['studentId'] ?? '';
    final String studentName = data['studentName'] ?? 'Student';
    final int year = (data['year'] as num?)?.toInt() ?? 2026;

    final TextEditingController subjectController =
        TextEditingController(text: data['subject'] ?? '');
    final TextEditingController feeController =
        TextEditingController(text: ((data['monthlyFee'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0));

    final Map<String, String> tempMonthStatuses = {};
    final savedStatuses = data['monthStatuses'] as Map<String, dynamic>?;

    for (var m in _months) {
      tempMonthStatuses[m] = savedStatuses?[m]?.toString() ?? 'NOT_ENROLLED';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final double monthlyFee = double.tryParse(feeController.text.trim()) ?? 0.0;
          final int paidCount = tempMonthStatuses.values.where((s) => s == 'PAID').length;
          final int dueCount = tempMonthStatuses.values.where((s) => s == 'DUE').length;
          final double totalPaid = paidCount * monthlyFee;
          final double totalDue = dueCount * monthlyFee;

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'UID: $studentId  •  $year',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      TextField(
                        controller: subjectController,
                        decoration: InputDecoration(
                          labelText: 'Subject Taught',
                          prefixIcon: Icon(Icons.menu_book_rounded, color: Colors.blue[800], size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: feeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Monthly Tuition Fee (₹)',
                          prefixIcon: Icon(Icons.currency_rupee_rounded, color: Colors.blue[800], size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5)),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
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
                                  const Text('Recalculated Paid', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                  Text('₹${totalPaid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Recalculated Due', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                    Text('₹${totalDue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '$year Monthly Ledger',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 10),
                      ..._months.map((m) {
                        final currentStatus = tempMonthStatuses[m] ?? 'NOT_ENROLLED';

                        Color badgeColor = const Color(0xFF64748B);
                        if (currentStatus == 'PAID') badgeColor = const Color(0xFF10B981);
                        if (currentStatus == 'DUE') badgeColor = const Color(0xFFEF4444);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(m, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  Text(
                                    currentStatus == 'PAID'
                                        ? 'PAID'
                                        : (currentStatus == 'DUE' ? 'DUE' : 'NOT ENROLLED'),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildMiniChip(
                                    label: 'Paid',
                                    isSelected: currentStatus == 'PAID',
                                    activeColor: const Color(0xFF10B981),
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setSheetState(() => tempMonthStatuses[m] = 'PAID');
                                    },
                                  ),
                                  _buildMiniChip(
                                    label: 'Due',
                                    isSelected: currentStatus == 'DUE',
                                    activeColor: const Color(0xFFEF4444),
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setSheetState(() => tempMonthStatuses[m] = 'DUE');
                                    },
                                  ),
                                  _buildMiniChip(
                                    label: 'Not Enrolled',
                                    isSelected: currentStatus == 'NOT_ENROLLED',
                                    activeColor: const Color(0xFF64748B),
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setSheetState(() => tempMonthStatuses[m] = 'NOT_ENROLLED');
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final batch = _firestore.batch();
                        final docRef = _firestore.collection('student_fees').doc(docId);

                        batch.update(docRef, {
                          'subject': subjectController.text.trim(),
                          'monthlyFee': monthlyFee,
                          'monthStatuses': tempMonthStatuses,
                          'paidMonthsCount': paidCount,
                          'dueMonthsCount': dueCount,
                          'totalPaid': totalPaid,
                          'totalDue': totalDue,
                          'lastUpdated': FieldValue.serverTimestamp(),
                        });

                        final monthlyRef = _firestore.collection('monthly_fee').doc(studentId);
                        batch.set(monthlyRef, {
                          'studentId': studentId,
                          'studentName': studentName,
                          'subject': subjectController.text.trim(),
                          'teacherId': widget.currentUserId,
                          'pendingAmount': totalDue,
                          'totalPaid': totalPaid,
                          'monthlyFee': monthlyFee,
                          'lastUpdated': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));

                        await batch.commit();

                        if (mounted) {
                          SuccessToast.show(context, 'Student Record Updated');
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to update student fee record')),
                          );
                        }
                      }
                    },
                    child: const Text('SAVE EDITED RECORD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniChip({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? activeColor : const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Diary History', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 19)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Student Name or UID...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filters.length,
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = filter),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue[800] : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              filter,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('student_fees')
                  .where('teacherId', isEqualTo: widget.currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 14),
                        const Text('No fee records created yet', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Add student fee records in My Diary to view history.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  );
                }

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final studentName = (data['studentName'] ?? '').toString().toLowerCase();
                  final studentId = (data['studentId'] ?? '').toString().toLowerCase();
                  final subject = (data['subject'] ?? '').toString().toLowerCase();
                  final double due = (data['totalDue'] as num?)?.toDouble() ?? 0.0;

                  final matchesSearch = studentName.contains(_searchQuery) ||
                      studentId.contains(_searchQuery) ||
                      subject.contains(_searchQuery);

                  bool matchesFilter = true;
                  if (_selectedFilter == 'Pending Dues') matchesFilter = due > 0;
                  if (_selectedFilter == 'Fully Paid') matchesFilter = due == 0;

                  return matchesSearch && matchesFilter;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text('No matching student fee records found.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final String studentName = data['studentName'] ?? 'Student';
                    final String studentId = data['studentId'] ?? '';
                    final String subject = data['subject'] ?? 'Not Specified';
                    final int year = (data['year'] as num?)?.toInt() ?? 2026;
                    final double monthlyFee = (data['monthlyFee'] as num?)?.toDouble() ?? 0.0;
                    final double totalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
                    final double totalDue = (data['totalDue'] as num?)?.toDouble() ?? 0.0;
                    final int dueMonths = (data['dueMonthsCount'] as num?)?.toInt() ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.blue.shade50,
                                child: Text(
                                  studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800], fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      studentName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      studentId,
                                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontFamily: 'monospace'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                             Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF1E40AF), size: 24),
                                  tooltip: 'Edit Fee & Subject',
                                  onPressed: () => _showEditStudentFeeSheet(doc),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.menu_book_rounded, size: 12, color: Colors.blue[800]),
                                    const SizedBox(width: 4),
                                    Text(
                                      subject,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: Text(
                                  'Year $year',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Monthly Fee', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Text('₹${monthlyFee.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Paid', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Text('₹${totalPaid.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981))),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Due ($dueMonths Mo)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Text(
                                    '₹${totalDue.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: totalDue > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
  }
}