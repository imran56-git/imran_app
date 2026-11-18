import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/success_toast.dart';

const List<String> _kMonths = [
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

String _formatCurrency(double amount) {
  return amount % 1 == 0
      ? amount.toInt().toString()
      : amount.toStringAsFixed(2);
}

String? _findCanonicalMonth(dynamic rawMonth) {
  final cleaned = (rawMonth ?? '').toString().trim().toLowerCase();
  if (cleaned.isEmpty) return null;
  for (final m in _kMonths) {
    if (m.toLowerCase() == cleaned) return m;
  }
  if (cleaned.length >= 3) {
    for (final m in _kMonths) {
      if (m.toLowerCase().startsWith(cleaned.substring(0, 3))) return m;
    }
  }
  return null;
}

String _normalizeStatus(dynamic rawStatus) {
  final s = (rawStatus ?? '').toString().trim().toUpperCase();
  if (s == 'PAID') return 'PAID';
  if (s == 'DUE' || s == 'PENDING') return 'DUE';
  return 'NOT_ENROLLED';
}

class _LedgerSummary {
  final Map<String, String> monthStatuses;
  final double monthlyFee;
  final int paidMonthsCount;
  final int dueMonthsCount;
  final double totalPaid;
  final double totalDue;

  const _LedgerSummary({
    required this.monthStatuses,
    required this.monthlyFee,
    required this.paidMonthsCount,
    required this.dueMonthsCount,
    required this.totalPaid,
    required this.totalDue,
  });

  factory _LedgerSummary.fromData(Map<String, dynamic> data) {
    final rawMap = (data['monthStatuses'] as Map?) ??
        (data['monthlyStatus'] as Map?) ??
        <String, dynamic>{};

    final Map<String, String> normalized = {
      for (final m in _kMonths) m: 'NOT_ENROLLED',
    };

    rawMap.forEach((key, value) {
      final canonical = _findCanonicalMonth(key);
      if (canonical != null) {
        normalized[canonical] = _normalizeStatus(value);
      }
    });

    final double monthlyFee = (data['monthlyFee'] is num)
        ? (data['monthlyFee'] as num).toDouble()
        : double.tryParse(data['monthlyFee']?.toString() ?? '0') ?? 0.0;

    final int paidCount =
        normalized.values.where((s) => s == 'PAID').length;
    final int dueCount = normalized.values.where((s) => s == 'DUE').length;

    return _LedgerSummary(
      monthStatuses: normalized,
      monthlyFee: monthlyFee,
      paidMonthsCount: paidCount,
      dueMonthsCount: dueCount,
      totalPaid: paidCount * monthlyFee,
      totalDue: dueCount * monthlyFee,
    );
  }
}

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
  final Set<String> _optimisticallyDeletedIds = {};

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
          imageUrl = data?['profileImageUrl'] ??
              data?['profilePic'] ??
              data?['imageUrl'];
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
                  errorBuilder: (_, __, ___) =>
                      _buildFallbackAvatar(studentName),
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
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  void _confirmDeleteDiary({
    required String docId,
    required String studentId,
    required String studentName,
    VoidCallback? onDeletedSuccess,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_forever_rounded,
                    color: Colors.red.shade600, size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Delete Record?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to remove the diary fee ledger for $studentName? This record and its calculations will be permanently deleted.',
            style: const TextStyle(
                fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(dialogCtx);
                      if (onDeletedSuccess != null) {
                        onDeletedSuccess();
                      }

                      setState(() {
                        _optimisticallyDeletedIds.add(docId);
                      });

                      try {
                        final parentRef =
                            _firestore.collection('student_fees').doc(docId);
                        final subEntries =
                            await parentRef.collection('fee_entries').get();

                        final batch = _firestore.batch();
                        for (final subDoc in subEntries.docs) {
                          batch.delete(subDoc.reference);
                        }
                        batch.delete(parentRef);
                        if (studentId.isNotEmpty) {
                          batch.delete(_firestore
                              .collection('monthly_fee')
                              .doc(studentId));
                        }
                        await batch.commit();

                        if (mounted) {
                          SuccessToast.show(context, 'Diary record deleted');
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            _optimisticallyDeletedIds.remove(docId);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Failed to delete student fee record')),
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showEditStudentFeeSheet(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final String docId = doc.id;
    final String studentId = (data['studentId'] ?? '').toString();
    final String studentName = (data['studentName'] ?? 'Student').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditLedgerSheet(
        docId: docId,
        data: data,
        currentUserId: widget.currentUserId,
        firestore: _firestore,
        avatar: _buildStudentAvatar(studentId, studentName),
        onRequestDelete: () => _confirmDeleteDiary(
          docId: docId,
          studentId: studentId,
          studentName: studentName,
          onDeletedSuccess: () => Navigator.pop(ctx),
        ),
        onSavedSuccess: () {
          if (mounted) {
            SuccessToast.show(context, 'Fee Ledger Updated & Balanced');
          }
        },
        onSaveError: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Failed to update student fee record')),
            );
          }
        },
      ),
    );
  }

  Widget _buildHeaderSummaryCard(List<DocumentSnapshot> docs) {
    double totalOutstanding = 0;
    double totalCollected = 0;
    int studentsWithDue = 0;

    for (var doc in docs) {
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      final summary = _LedgerSummary.fromData(data);
      totalOutstanding += summary.totalDue;
      totalCollected += summary.totalPaid;
      if (summary.totalDue > 0) studentsWithDue++;
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
                const Text('Total Outstanding Due',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('₹${_formatCurrency(totalOutstanding)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$studentsWithDue Students with Pending Due',
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
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
                  const Text('Total Collected',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('₹${_formatCurrency(totalCollected)}',
                      style: const TextStyle(
                          color: Color(0xFF6EE7B7),
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${docs.length} Total Enrolled',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
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
        title: const Text('Diary History',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 19)),
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
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E40AF)));
          }

          final allDocs =
              snapshot.hasData ? snapshot.data!.docs : <DocumentSnapshot>[];
          final activeDocs = allDocs
              .where((doc) => !_optimisticallyDeletedIds.contains(doc.id))
              .toList();

          return Column(
            children: [
              if (activeDocs.isNotEmpty) _buildHeaderSummaryCard(activeDocs),
              Container(
                color: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by Student Name or UID...',
                        hintStyle:
                            TextStyle(color: Colors.grey[400], fontSize: 14),
                        prefixIcon:
                            const Icon(Icons.search_rounded, color: Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    size: 18, color: Colors.grey),
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
                          borderSide: BorderSide(
                              color: Colors.blue.shade400, width: 1.5),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
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
                            onTap: () =>
                                setState(() => _selectedFilter = filter),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue[800]
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blue[800]!
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF334155),
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
                    if (activeDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 14),
                            const Text('No fee records created yet',
                                style: TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(
                                'Add student fee records in My Diary to view history.',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    final filteredDocs = activeDocs.where((doc) {
                      final data =
                          (doc.data() as Map<String, dynamic>?) ?? {};
                      final studentName =
                          (data['studentName'] ?? '').toString().toLowerCase();
                      final studentId =
                          (data['studentId'] ?? '').toString().toLowerCase();
                      final subject =
                          (data['subject'] ?? '').toString().toLowerCase();
                      final summary = _LedgerSummary.fromData(data);

                      final matchesSearch = studentName.contains(_searchQuery) ||
                          studentId.contains(_searchQuery) ||
                          subject.contains(_searchQuery);

                      bool matchesFilter = true;
                      if (_selectedFilter == 'Pending Dues') {
                        matchesFilter = summary.totalDue > 0;
                      }
                      if (_selectedFilter == 'Fully Paid') {
                        matchesFilter = summary.totalDue == 0;
                      }

                      return matchesSearch && matchesFilter;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Text('No matching student fee records found.',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 14)),
                      );
                    }

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data =
                            (doc.data() as Map<String, dynamic>?) ?? {};

                        final String studentName =
                            (data['studentName'] ?? 'Student').toString();
                        final String studentId =
                            (data['studentId'] ?? '').toString();
                        final String subject =
                            (data['subject'] ?? 'Not Specified').toString();
                        final int year =
                            (data['year'] as num?)?.toInt() ?? DateTime.now().year;

                        final summary = _LedgerSummary.fromData(data);

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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          studentName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Color(0xFF0F172A)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          studentId,
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              color: Colors.grey.shade500,
                                              fontFamily: 'monospace'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 22),
                                      tooltip: 'Delete Diary Record',
                                      onPressed: () => _confirmDeleteDiary(
                                        docId: doc.id,
                                        studentId: studentId,
                                        studentName: studentName,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.edit_note_rounded,
                                          color: Color(0xFF1E40AF), size: 24),
                                      tooltip: 'Update Payment Status',
                                      onPressed: () =>
                                          _showEditStudentFeeSheet(doc),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.menu_book_rounded,
                                              size: 12,
                                              color: Colors.blue[800]),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              subject.isEmpty
                                                  ? 'Not Specified'
                                                  : subject,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF334155)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: Colors.amber.shade200),
                                    ),
                                    child: Text(
                                      'Year $year',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Color(0xFFF1F5F9)),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Monthly Fee',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B))),
                                      Text(
                                          '₹${_formatCurrency(summary.monthlyFee)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF0F172A))),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Paid',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B))),
                                      Text(
                                          '₹${_formatCurrency(summary.totalPaid)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF10B981))),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Due (${summary.dueMonthsCount} Mo)',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B))),
                                      Text(
                                        '₹${_formatCurrency(summary.totalDue)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: summary.totalDue > 0
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF10B981),
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

class _EditLedgerSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String currentUserId;
  final FirebaseFirestore firestore;
  final Widget avatar;
  final VoidCallback onRequestDelete;
  final VoidCallback onSavedSuccess;
  final VoidCallback onSaveError;

  const _EditLedgerSheet({
    required this.docId,
    required this.data,
    required this.currentUserId,
    required this.firestore,
    required this.avatar,
    required this.onRequestDelete,
    required this.onSavedSuccess,
    required this.onSaveError,
  });

  @override
  State<_EditLedgerSheet> createState() => _EditLedgerSheetState();
}

class _EditLedgerSheetState extends State<_EditLedgerSheet> {
  late TextEditingController _subjectController;
  late TextEditingController _feeController;
  late Map<String, String> _tempMonthStatuses;
  late String _studentId;
  late String _studentName;
  late int _year;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _studentId = (widget.data['studentId'] ?? '').toString();
    _studentName = (widget.data['studentName'] ?? 'Student').toString();
    _year = (widget.data['year'] as num?)?.toInt() ?? DateTime.now().year;

    final summary = _LedgerSummary.fromData(widget.data);
    _tempMonthStatuses = Map<String, String>.from(summary.monthStatuses);

    _subjectController =
        TextEditingController(text: (widget.data['subject'] ?? '').toString());
    _feeController = TextEditingController(
      text: summary.monthlyFee > 0 ? _formatCurrency(summary.monthlyFee) : '0',
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final double monthlyFee =
        double.tryParse(_feeController.text.trim()) ?? 0.0;
    final int paidCount =
        _tempMonthStatuses.values.where((s) => s == 'PAID').length;
    final int dueCount =
        _tempMonthStatuses.values.where((s) => s == 'DUE').length;
    final double totalPaid = paidCount * monthlyFee;
    final double totalDue = dueCount * monthlyFee;

    try {
      final batch = widget.firestore.batch();
      final docRef =
          widget.firestore.collection('student_fees').doc(widget.docId);

      batch.update(docRef, {
        'subject': _subjectController.text.trim(),
        'monthlyFee': monthlyFee,
        'monthStatuses': _tempMonthStatuses,
        'paidMonthsCount': paidCount,
        'dueMonthsCount': dueCount,
        'gridDueAmount': totalDue,
        'totalPaid': totalPaid,
        'totalCollected': totalPaid,
        'totalDue': totalDue,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (_studentId.isNotEmpty) {
        final monthlyRef =
            widget.firestore.collection('monthly_fee').doc(_studentId);
        batch.set(
          monthlyRef,
          {
            'studentId': _studentId,
            'studentName': _studentName,
            'subject': _subjectController.text.trim(),
            'teacherId': widget.currentUserId,
            'pendingAmount': totalDue,
            'totalPaid': totalPaid,
            'monthlyFee': monthlyFee,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      final entriesSnap = await docRef.collection('fee_entries').get();
      for (final entryDoc in entriesSnap.docs) {
        final entryData = entryDoc.data();
        final canonicalMonth =
            _findCanonicalMonth(entryData['month'] ?? entryData['monthName']);
        if (canonicalMonth != null) {
          final targetStatus = _tempMonthStatuses[canonicalMonth];
          final existingStatus =
              (entryData['status'] ?? '').toString().toLowerCase();
          if (targetStatus == 'PAID' && existingStatus != 'paid') {
            batch.update(entryDoc.reference, {
              'status': 'paid',
              'paidAt': FieldValue.serverTimestamp(),
            });
          } else if (targetStatus == 'DUE' && existingStatus == 'paid') {
            batch.update(entryDoc.reference, {
              'status': 'due',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSavedSuccess();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      widget.onSaveError();
    }
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
            border: Border.all(
                color: isSelected ? activeColor : const Color(0xFFE2E8F0)),
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
    final double monthlyFee =
        double.tryParse(_feeController.text.trim()) ?? 0.0;
    final int paidCount =
        _tempMonthStatuses.values.where((s) => s == 'PAID').length;
    final int dueCount =
        _tempMonthStatuses.values.where((s) => s == 'DUE').length;
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
                    widget.avatar,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _studentName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'UID: $_studentId  •  $_year',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey[600],
                                fontFamily: 'monospace'),
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
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 20),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                TextField(
                  controller: _subjectController,
                  decoration: InputDecoration(
                    labelText: 'Subject Taught',
                    prefixIcon: Icon(Icons.menu_book_rounded,
                        color: Colors.blue[800], size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.blue.shade400, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _feeController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Monthly Tuition Fee (₹)',
                    prefixIcon: Icon(Icons.currency_rupee_rounded,
                        color: Colors.blue[800], size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.blue.shade400, width: 1.5)),
                  ),
                  onChanged: (_) => setState(() {}),
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
                            const Text('Total Collected',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('₹${_formatCurrency(totalPaid)}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981))),
                            Text('$paidCount Months Paid',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.grey.shade500)),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Outstanding Due',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                '₹${_formatCurrency(totalDue)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: totalDue > 0
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF10B981),
                                ),
                              ),
                              Text('Due ($dueCount Mo)',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '$_year Monthly Status Ledger',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                ..._kMonths.map((m) {
                  final currentStatus =
                      _tempMonthStatuses[m] ?? 'NOT_ENROLLED';

                  Color badgeColor = const Color(0xFF64748B);
                  if (currentStatus == 'PAID') {
                    badgeColor = const Color(0xFF10B981);
                  }
                  if (currentStatus == 'DUE') {
                    badgeColor = const Color(0xFFEF4444);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentStatus == 'DUE'
                            ? Colors.red.shade200
                            : const Color(0xFFE2E8F0),
                        width: currentStatus == 'DUE' ? 1.2 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(m,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                currentStatus == 'PAID'
                                    ? 'PAID'
                                    : (currentStatus == 'DUE'
                                        ? 'DUE'
                                        : 'NOT ENROLLED'),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColor),
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
                                setState(
                                    () => _tempMonthStatuses[m] = 'PAID');
                              },
                            ),
                            _buildMiniChip(
                              label: 'Due',
                              isSelected: currentStatus == 'DUE',
                              activeColor: const Color(0xFFEF4444),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _tempMonthStatuses[m] = 'DUE');
                              },
                            ),
                            _buildMiniChip(
                              label: 'Not Enrolled',
                              isSelected: currentStatus == 'NOT_ENROLLED',
                              activeColor: const Color(0xFF64748B),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() =>
                                    _tempMonthStatuses[m] = 'NOT_ENROLLED');
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
          Row(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent, size: 24),
                  tooltip: 'Delete Record',
                  onPressed: widget.onRequestDelete,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    onPressed: _isSaving ? null : _saveEdits,
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'SAVE EDITED RECORD',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                                letterSpacing: 0.5),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

---

### Ready for File #6
Please paste the complete current code for **File #6** — your **Teacher Dashboard** file containing the **Pending Tuition Fees** popup (please include its exact `lib/...` file path, and also confirm the file path for your **FYBTT Chats** screen!).
### Inspection & Fixes Applied to `teacher_dashboard_screen.dart`

I inspected `TeacherDashboardScreen` and fixed a critical syntax error plus the Pending Tuition Fees ledger sync:

1. **Compile Error Fixed (Line 206):** Replaced the invalid `TextOverflow(ellipsis: null).ellipsis` expression in the Pending Tuition Fees popup with `TextOverflow.ellipsis`.
2. **Dynamic Monthly Ledger Sync in Pending Tuition Fees Popup:** Updated `_checkAndShowPendingDuesPopup` so `totalDue` and `Due (X Mo)` are calculated dynamically from each student's `monthStatuses` (with `monthlyStatus` fallback) and `monthlyFee`, matching `DiaryScreen` and `DiaryHistoryScreen` 100%.
3. **Decimal & Empty-Subject Formatting:** Added clean currency formatting (`₹1000` or `₹1000.50`) and fell back to `'Tuition'` when `subject` is blank.
4. **Null-Safety & Stream Guards:** Added empty-`uid` guards on the notification and chat hub streams, null-safe Firestore map casts, and removed unused imports (`chat_screen.dart`, `teacher_detail_screen.dart`) to keep the analyzer warning-free.

---

### Complete Updated File #6: `teacher_dashboard_screen.dart`

```dart
import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/reminder_service.dart';
import '../../services/user_service.dart';
import '../../widgets/verification_badge.dart';
import '../common/chat_hub_screen.dart';
import '../common/leaderboard_screen.dart';
import '../common/my_connections_screen.dart';
import '../common/notifications_screen.dart';
import '../common/profile_screen.dart';
import '../common/subscription_screen.dart';
import 'create_post_screen.dart';
import 'diary_screen.dart';
import 'reminder_screen.dart';
import 'teacher_profile_setup_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final ReminderService _reminderService = ReminderService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _teacherData;
  bool _isLoading = true;
  bool _hasCheckedPendingPopup = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _reminderTimer;

  static const Color _primaryBlue = Color(0xFF1565C0);
  static const Color _bgColor = Color(0xFFF5F7FB);

  static const List<String> _months = [
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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadTeacherData();

    _reminderTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final uid = _userService.currentUserId;
      if (uid != null && uid.isNotEmpty) {
        _reminderService.checkAndProcessDueReminders(currentUserId: uid);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _reminderTimer?.cancel();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
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

  ({int dueMonths, double totalDue}) _computeDueFromMonthlyMap(
      Map<String, dynamic> data) {
    final rawMap = (data['monthStatuses'] as Map?) ??
        (data['monthlyStatus'] as Map?) ??
        <String, dynamic>{};

    final Map<String, String> normalized = {
      for (final m in _months) m: 'NOT_ENROLLED',
    };

    rawMap.forEach((key, value) {
      final canonical = _findCanonicalMonth(key);
      if (canonical != null) {
        final s = (value ?? '').toString().trim().toUpperCase();
        if (s == 'PAID') {
          normalized[canonical] = 'PAID';
        } else if (s == 'DUE' || s == 'PENDING') {
          normalized[canonical] = 'DUE';
        } else {
          normalized[canonical] = 'NOT_ENROLLED';
        }
      }
    });

    final int dueMonths =
        normalized.values.where((s) => s == 'DUE').length;
    final double monthlyFee = (data['monthlyFee'] is num)
        ? (data['monthlyFee'] as num).toDouble()
        : double.tryParse(data['monthlyFee']?.toString() ?? '0') ?? 0.0;

    return (dueMonths: dueMonths, totalDue: dueMonths * monthlyFee);
  }

  Future<void> _loadTeacherData() async {
    final uid = _userService.currentUserId;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      await _reminderService.checkAndProcessDueReminders(currentUserId: uid);

      final doc = await _firestore.collection('teachers').doc(uid).get();
      if (!mounted) return;
      if (doc.exists) {
        setState(() {
          _teacherData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }

      if (!_hasCheckedPendingPopup) {
        _hasCheckedPendingPopup = true;
        _checkAndShowPendingDuesPopup(uid);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAndShowPendingDuesPopup(String uid) async {
    try {
      final feeDocs = await _firestore
          .collection('student_fees')
          .where('teacherId', isEqualTo: uid)
          .get();

      final List<({String name, String subject, int dueMonths, double due})>
          pendingList = [];
      double grandTotalDue = 0;

      for (final doc in feeDocs.docs) {
        final data = doc.data();
        final summary = _computeDueFromMonthlyMap(data);
        if (summary.totalDue > 0) {
          final String name = (data['studentName'] ?? 'Student').toString();
          final String rawSubject = (data['subject'] ?? '').toString().trim();
          final String subject = rawSubject.isNotEmpty ? rawSubject : 'Tuition';
          pendingList.add((
            name: name,
            subject: subject,
            dueMonths: summary.dueMonths,
            due: summary.totalDue,
          ));
          grandTotalDue += summary.totalDue;
        }
      }

      if (pendingList.isNotEmpty && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Dismiss',
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, anim1, anim2) => const SizedBox(),
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
                        borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.redAccent,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pending Tuition Fees',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'Students with due balances',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.normal),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${pendingList.length} Student${pendingList.length > 1 ? 's' : ''} Pending',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade900,
                                      fontSize: 13),
                                ),
                                Text(
                                  '₹${_formatCurrency(grandTotalDue)}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.red.shade700,
                                      fontSize: 17),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: pendingList.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 12),
                              itemBuilder: (context, index) {
                                final item = pendingList[index];
                                return Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.blue.shade50,
                                      child: Text(
                                        item.name.isNotEmpty
                                            ? item.name[0].toUpperCase()
                                            : 'S',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800,
                                            fontSize: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Color(0xFF0F172A)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${item.subject} • Due (${item.dueMonths} Mo)',
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                color: Colors.grey.shade600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '₹${_formatCurrency(item.due)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.redAccent,
                                          fontSize: 14),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close',
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DiaryScreen(
                                currentUserId: uid,
                                currentUserName:
                                    (_teacherData?['name'] ?? 'Teacher')
                                        .toString(),
                              ),
                            ),
                          );
                        },
                        child: const Text('Open Diary',
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
    } catch (_) {}
  }

  Widget _buildVerifiedHeaderBadge() {
    final badgeData =
        _teacherData?['verificationBadge'] as Map<String, dynamic>?;
    final bool isVerified =
        badgeData != null && badgeData['isVerified'] == true;
    final String planType =
        (badgeData?['planType'] ?? 'none').toString().toLowerCase();

    if (!isVerified && planType == 'none') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 5),
      child: VerificationBadge(
        planType: planType == 'none' ? 'blue' : planType,
        size: 16,
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  Widget _buildMyStatsCard(String uid) {
    final String name = (_teacherData?['name'] ?? 'Teacher').toString();
    final String photoUrl = (_teacherData?['profileImageUrl'] ??
            _teacherData?['photoUrl'] ??
            '')
        .toString();
    final String specialization = (_teacherData?['subjectSpecialization'] ??
            _teacherData?['subjects'] ??
            'Educator')
        .toString();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeacherProfileSetupScreen(),
                      ),
                    ).then((_) => _loadTeacherData());
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.6), width: 2),
                    ),
                    child: ClipOval(
                      child: photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildVerifiedHeaderBadge(),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        specialization,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit Profile',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TeacherProfileSetupScreen()),
                    ).then((_) => _loadTeacherData());
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot>(
              stream: uid.isEmpty
                  ? null
                  : _firestore.collection('teachers').doc(uid).snapshots(),
              builder: (context, snapshot) {
                final data =
                    (snapshot.data?.data() as Map<String, dynamic>?) ??
                        _teacherData ??
                        {};
                final int views = (data['profileViews'] as num?)?.toInt() ?? 0;
                final int likes = (data['likesCount'] as num?)?.toInt() ?? 0;
                final int connections =
                    (data['followersCount'] as num?)?.toInt() ?? 0;

                return Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statColumn('Profile Views', _formatCount(views),
                          Icons.visibility_rounded),
                      Container(width: 1, height: 28, color: Colors.white24),
                      _statColumn('Total Likes', _formatCount(likes),
                          Icons.favorite_rounded),
                      Container(width: 1, height: 28, color: Colors.white24),
                      InkWell(
                        onTap: () {
                          if (uid.isEmpty) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MyConnectionsScreen(
                                  currentUserId: uid, userRole: 'teacher'),
                            ),
                          );
                        },
                        child: _statColumn(
                            'Connections',
                            _formatCount(connections),
                            Icons.people_alt_rounded),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 11,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildActionCenterGrid(String uid, String teacherName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Teacher Toolkit',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A)),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _actionTile(
                  title: 'My Diary',
                  subtitle: 'Fee Ledger',
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFF0284C7),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DiaryScreen(
                            currentUserId: uid, currentUserName: teacherName),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionTile(
                  title: 'Fee Reminder',
                  subtitle: 'Official Alerts',
                  icon: Icons.notifications_active_rounded,
                  color: const Color(0xFF059669),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReminderScreen(
                            currentUserId: uid, currentUserName: teacherName),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionTile(
                  title: 'Create Post',
                  subtitle: 'Share Updates',
                  icon: Icons.add_photo_alternate_rounded,
                  color: const Color(0xFF7C3AED),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreatePostScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionTile(
                  title: 'Leaderboard',
                  subtitle: 'Top Educators',
                  icon: Icons.emoji_events_rounded,
                  color: const Color(0xFFD97706),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LeaderboardScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyBanner() {
    final badgeData =
        _teacherData?['verificationBadge'] as Map<String, dynamic>?;
    final bool isVerified =
        badgeData != null && badgeData['isVerified'] == true;
    if (isVerified) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: Color(0xFF38BDF8), size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Get Verified Educator Badge',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      Text(
                        'Boost student trust & rank higher in search',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Upgrade',
                    style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyPostsSection(String uid) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'My Recent Posts',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A)),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: uid.isEmpty
                ? null
                : _firestore
                    .collection('posts')
                    .where('authorId', isEqualTo: uid)
                    .limit(10)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator()));
              }

              final docs = [...(snapshot.data?.docs ?? [])];
              docs.sort((a, b) {
                final aMap = (a.data() as Map<String, dynamic>?) ?? {};
                final bMap = (b.data() as Map<String, dynamic>?) ?? {};
                final aTs = aMap['createdAt'] as Timestamp?;
                final bTs = bMap['createdAt'] as Timestamp?;
                return (bTs?.millisecondsSinceEpoch ?? 0)
                    .compareTo(aTs?.millisecondsSinceEpoch ?? 0);
              });

              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.article_outlined,
                          size: 42, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      const Text('No posts published yet',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155))),
                      const SizedBox(height: 4),
                      Text(
                          'Share tips, study material or updates with students.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final data =
                      (docs[index].data() as Map<String, dynamic>?) ?? {};
                  final String text =
                      (data['content'] ?? data['caption'] ?? '').toString();
                  final String imageUrl = (data['imageUrl'] ?? '').toString();
                  final int likes = (data['likesCount'] as num?)?.toInt() ?? 0;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (text.isNotEmpty)
                          Text(
                            text,
                            style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF1E293B),
                                height: 1.4),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (imageUrl.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.favorite_rounded,
                                size: 15, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text('$likes Likes',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBell(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: uid.isEmpty
          ? null
          : _firestore
              .collection('notifications')
              .where('receiverId', isEqualTo: uid)
              .where('isRead', isEqualTo: false)
              .snapshots(),
      builder: (context, snapshot) {
        final int unread = snapshot.data?.docs.length ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded,
                  color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                );
              },
            ),
            if (unread > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.redAccent, shape: BoxShape.circle),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildChatHubIcon(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: uid.isEmpty
          ? null
          : _firestore
              .collection('chats')
              .where('participants', arrayContains: uid)
              .snapshots(),
      builder: (context, snapshot) {
        int totalUnread = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = (doc.data() as Map<String, dynamic>?) ?? {};
            final deletedBy = List<String>.from(data['deletedBy'] ?? []);
            if (deletedBy.contains(uid)) continue;
            final unreadCount = (data['unreadCount_$uid'] as num?)?.toInt() ??
                (data['unreadFor'] == uid
                    ? (data['unreadCount'] as num?)?.toInt() ?? 0
                    : 0);
            totalUnread += unreadCount;
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded,
                  color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatHubScreen()),
                );
              },
            ),
            if (totalUnread > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Color(0xFF10B981), shape: BoxShape.circle),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    totalUnread > 99 ? '99+' : '$totalUnread',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _userService.currentUserId ?? '';
    final teacherName = (_teacherData?['name'] ?? 'Teacher').toString();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primaryBlue,
        elevation: 0,
        title: const Text(
          'FYBTT Educator',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19),
        ),
        actions: [
          _buildNotificationBell(uid),
          _buildChatHubIcon(uid),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeacherData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMyStatsCard(uid),
                    _buildVerifyBanner(),
                    _buildActionCenterGrid(uid, teacherName),
                    _buildMyPostsSection(uid),
                  ],
                ),
              ),
            ),
    );
  }
}