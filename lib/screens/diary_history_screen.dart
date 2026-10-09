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

  Widget _buildStudentAvatar(String studentId, String studentName) {
    if (studentId.isEmpty) {
      return _buildFallbackAvatar(studentName);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('students').doc(studentId).get(),
      builder: (context, snapshot) {
        String? imageUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          imageUrl = data?['profileImageUrl'] ?? data?['profilePic'] ?? data?['imageUrl'];
        }

        if (imageUrl != null && imageUrl.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.network(
              imageUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackAvatar(studentName),
            ),
          );
        }

        return FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(studentId).get(),
          builder: (context, userSnap) {
            String? userImg;
            if (userSnap.hasData && userSnap.data!.exists) {
              final uData = userSnap.data!.data() as Map<String, dynamic>?;
              userImg = uData?['profileImageUrl'] ?? uData?['photoUrl'];
            }

            if (userImg != null && userImg.isNotEmpty) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.network(
                  userImg,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildFallbackAvatar(studentName),
                ),
              );
            }

            return _buildFallbackAvatar(studentName);
          },
        );
      },
    );
  }

  Widget _buildFallbackAvatar(String name) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'S',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  void _showEditStudentFeeSheet(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String docId = doc.id;
    final String studentId = (data['studentId'] ?? '').toString();
    final String studentName = (data['studentName'] ?? 'Student').toString();
    final int year = (data['year'] as num?)?.toInt() ?? DateTime.now().year;

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
                      child: Row(
                        children: [
                          _buildStudentAvatar(studentId, studentName),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'UID: $studentId  •  $year',
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600], fontFamily: 'monospace'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
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
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Collected', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('₹${totalPaid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                  Text('$paidCount Months Paid', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
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
                                    const Text('Pending Due', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text('₹${totalDue.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: totalDue > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981))),
                                    Text('$dueCount Months Pending', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '$year Monthly Status Ledger',
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
                            border: Border.all(
                              color: currentStatus == 'DUE' ? Colors.red.shade200 : const Color(0xFFE2E8F0),
                              width: currentStatus == 'DUE' ? 1.2 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(m, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      currentStatus == 'PAID'
                                          ? 'PAID'
                                          : (currentStatus == 'DUE' ? 'DUE' : 'NOT ENROLLED'),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor),
                                    ),
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
                          SuccessToast.show(context, 'Fee Ledger Updated & Balanced');
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

  Widget _buildHeaderSummaryCard(List<DocumentSnapshot> docs) {
    double totalOutstanding = 0;
    double totalCollected = 0;
    int studentsWithDue = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final double due = (data['totalDue'] as num?)?.toDouble() ?? 0.0;
      final double paid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
      totalOutstanding += due;
      totalCollected += paid;
      if (due > 0) studentsWithDue++;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Outstanding Due', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('₹${totalOutstanding.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$studentsWithDue Students with Pending Due', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(width: 1, height: 48, color: Colors.white24),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Collected', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('₹${totalCollected.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${docs.length} Total Enrolled', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('student_fees')
            .where('teacherId', isEqualTo: widget.currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1E40AF)));
          }

          final allDocs = snapshot.hasData ? snapshot.data!.docs : <DocumentSnapshot>[];

          return Column(
            children: [
              if (allDocs.isNotEmpty) _buildHeaderSummaryCard(allDocs),
              Container(
                color: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                        fillColor: Colors.white,
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
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
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
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue[800] : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? Colors.blue[800]! : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFF334155),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
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
                child: Builder(
                  builder: (context) {
                    if (allDocs.isEmpty) {
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

                    final filteredDocs = allDocs.where((doc) {
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;

                        final String studentName = (data['studentName'] ?? 'Student').toString();
                        final String studentId = (data['studentId'] ?? '').toString();
                        final String subject = (data['subject'] ?? 'Not Specified').toString();
                        final int year = (data['year'] as num?)?.toInt() ?? DateTime.now().year;
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
                                  _buildStudentAvatar(studentId, studentName),
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
                                      tooltip: 'Update Payment Status',
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
          );
        },
      ),
    );
  }
}