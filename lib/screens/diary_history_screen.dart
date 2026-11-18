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
    final Map<String, String> normalized = {
      for (final m in _kMonths) m: 'NOT_ENROLLED',
    };

    // 1. Ingest monthlyStatus map (standard key from functions and fee reminders)
    final monthlyStatusMap = (data['monthlyStatus'] as Map?) ?? {};
    monthlyStatusMap.forEach((key, value) {
      final canonical = _findCanonicalMonth(key);
      if (canonical != null) {
        normalized[canonical] = _normalizeStatus(value);
      }
    });

    // 2. Ingest monthStatuses map if present
    final monthStatusesMap = (data['monthStatuses'] as Map?) ?? {};
    monthStatusesMap.forEach((key, value) {
      final canonical = _findCanonicalMonth(key);
      if (canonical != null) {
        final s = _normalizeStatus(value);
        if (normalized[canonical] == 'NOT_ENROLLED' || s != 'NOT_ENROLLED') {
          normalized[canonical] = s;
        }
      }
    });

    // 3. Fallback to direct root month fields (e.g. data['November'])
    for (final m in _kMonths) {
      final directVal = data[m] ?? data[m.toLowerCase()];
      if (directVal != null) {
        final s = _normalizeStatus(directVal);
        if (s != 'NOT_ENROLLED') {
          normalized[m] = s;
        }
      }
    }

    final double monthlyFee = (data['monthlyFee'] is num)
        ? (data['monthlyFee'] as num).toDouble()
        : (data['feeAmount'] is num)
            ? (data['feeAmount'] as num).toDouble()
            : double.tryParse(data['monthlyFee']?.toString() ??
                    data['feeAmount']?.toString() ??
                    '0') ??
                0.0;

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

  Widget _buildStudentAvatar({
    required String studentId,
    required String studentName,
    String? directPhotoUrl,
    double size = 44,
  }) {
    final initials = studentName.trim().isNotEmpty
        ? studentName
            .trim()
            .split(' ')
            .where((p) => p.isNotEmpty)
            .map((e) => e[0])
            .take(2)
            .join()
            .toUpperCase()
        : 'ST';

    Widget fallback() => Container(
          width: size,
          height: size,
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
              initials,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: size * 0.36,
              ),
            ),
          ),
        );

    if (directPhotoUrl != null && directPhotoUrl.trim().isNotEmpty) {
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Image.network(
          directPhotoUrl.trim(),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      );
    }

    if (studentId.isEmpty) {
      return fallback();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('students').doc(studentId).get(),
      builder: (context, snapshot) {
        String? imageUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          imageUrl = data?['profileImageUrl'] ??
              data?['profilePic'] ??
              data?['imageUrl'] ??
              data?['photoUrl'];
        }

        if (imageUrl != null && imageUrl.trim().isNotEmpty) {
          return Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Image.network(
              imageUrl.trim(),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback(),
            ),
          );
        }

        return FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(studentId).get(),
          builder: (context, userSnap) {
            String? userImg;
            if (userSnap.hasData && userSnap.data!.exists) {
              final uData = userSnap.data!.data() as Map<String, dynamic>?;
              userImg = uData?['profileImageUrl'] ??
                  uData?['photoUrl'] ??
                  uData?['avatarUrl'];
            }

            if (userImg != null && userImg.trim().isNotEmpty) {
              return Container(
                width: size,
                height: size,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Image.network(
                  userImg.trim(),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback(),
                ),
              );
            }

            return fallback();
          },
        );
      },
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
    final String? directPhoto = data['profileImageUrl']?.toString() ??
        data['photoUrl']?.toString() ??
        data['studentPhotoUrl']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditLedgerSheet(
        docId: docId,
        data: data,
        currentUserId: widget.currentUserId,
        firestore: _firestore,
        avatar: _buildStudentAvatar(
          studentId: studentId,
          studentName: studentName,
          directPhotoUrl: directPhoto,
        ),
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
                        final String? directPhoto =
                            data['profileImageUrl']?.toString() ??
                                data['photoUrl']?.toString() ??
                                data['studentPhotoUrl']?.toString();

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
                                  _buildStudentAvatar(
                                    studentId: studentId,
                                    studentName: studentName,
                                    directPhotoUrl: directPhoto,
                                  ),
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

    final Map<String, String> standardLowerStatus = {};
    final Map<String, String> standardUpperStatus = {};

    for (final m in _kMonths) {
      final norm = _normalizeStatus(_tempMonthStatuses[m]);
      standardUpperStatus[m] = norm;
      standardLowerStatus[m] =
          norm == 'PAID' ? 'paid' : (norm == 'DUE' ? 'due' : 'not_enrolled');
    }

    try {
      final batch = widget.firestore.batch();
      final docRef =
          widget.firestore.collection('student_fees').doc(widget.docId);

      final Map<String, dynamic> updatePayload = {
        'subject': _subjectController.text.trim(),
        'monthlyFee': monthlyFee,
        'feeAmount': monthlyFee,
        'monthlyStatus': standardLowerStatus,
        'monthStatuses': standardUpperStatus,
        'paidMonthsCount': paidCount,
        'paidMonths': paidCount,
        'dueMonthsCount': dueCount,
        'dueMonths': dueCount,
        'gridDueAmount': totalDue,
        'totalPaid': totalPaid,
        'totalCollected': totalPaid,
        'totalDue': totalDue,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Set direct root keys for flat reads
      for (final m in _kMonths) {
        updatePayload[m] = standardLowerStatus[m];
      }

      batch.update(docRef, updatePayload);

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
            'totalDue': totalDue,
            'totalPaid': totalPaid,
            'monthlyFee': monthlyFee,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // Sync fee_entries subcollection
      final entriesSnap = await docRef.collection('fee_entries').get();
      final existingEntriesByMonth = <String, DocumentSnapshot>{};
      for (final d in entriesSnap.docs) {
        final rawM = d.data()['month'] ?? d.data()['monthName'];
        final canonical = _findCanonicalMonth(rawM);
        if (canonical != null) {
          existingEntriesByMonth[canonical] = d;
        }
      }

      for (final m in _kMonths) {
        final targetStatus = standardLowerStatus[m]!;
        if (existingEntriesByMonth.containsKey(m)) {
          final entryDoc = existingEntriesByMonth[m]!;
          batch.update(entryDoc.reference, {
            'status': targetStatus,
            'amount': monthlyFee,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (targetStatus != 'not_enrolled') {
          final newEntry = docRef.collection('fee_entries').doc();
          batch.set(newEntry, {
            'entryId': newEntry.id,
            'month': m,
            'amount': monthlyFee,
            'status': targetStatus,
            'source': 'ledger_editor',
            'createdAt': FieldValue.serverTimestamp(),
          });
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