import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/success_toast.dart';

class DiaryHistoryScreen extends StatefulWidget {
  final String currentUserId;

  const DiaryHistoryScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<DiaryHistoryScreen> createState() => _DiaryHistoryScreenState();
}

class _DiaryHistoryScreenState extends State<DiaryHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final List<String> _filters = ['All', 'Present', 'Absent', 'Fees Pending'];

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

  // ডাইনামিক এন্ট্রি আপডেট ডায়ালগ (মেকানিজম)
  void _showUpdateDialog(Map<String, dynamic> diaryData) {
    String localAttendance = diaryData['attendanceStatus'] ?? 'Present';
    String localFeeStatus = diaryData['feeStatus'] ?? 'NO';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, a1, a2) => const SizedBox(),
      transitionBuilder: (context, anim, a2, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  title: const Text(
                    'Update Diary Entry',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B1B1B), fontSize: 18),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: localAttendance,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ['Present', 'Absent', 'Late', 'Holiday'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                        onChanged: (val) => setDialogState(() => localAttendance = val!),
                      ),
                      const SizedBox(height: 18),
                      const Text('Fee Status (Selected Month)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: localFeeStatus,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ['YES', 'NO'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                        onChanged: (val) => setDialogState(() => localFeeStatus = val!),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          final String diaryId = diaryData['diaryId'];
                          final String studentId = diaryData['studentId'];
                          final String month = diaryData['month'] ?? 'January';

                          final batch = _firestore.batch();
                          
                          // ১. ডায়েরি কালেকশন এন্ট্রি আপডেট
                          batch.update(_firestore.collection('diary').doc(diaryId), {
                            'attendanceStatus': localAttendance,
                            'feeStatus': localFeeStatus,
                          });

                          // ২. লেজার ট্র্যাকিং পজিশন সিঙ্ক আপডেট
                          batch.set(_firestore.collection('monthly_fee').doc(studentId), {
                            'feeStatus12Months.$month': localFeeStatus,
                            'lastUpdated': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                          await batch.commit();
                          if (mounted) {
                            SuccessToast.show(context, 'Entry Updated Successfully');
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to update data')),
                          );
                        }
                      },
                      child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Student Name or UID...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
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
                const SizedBox(height: 14),
                SizedBox(
                  height: 38,
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
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
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
                                fontSize: 13,
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
                  .collection('diary')
                  .where('teacherId', isEqualTo: widget.currentUserId)
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('No diary entries found.', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                  );
                }

                // ক্লায়েন্ট-সাইড ফিল্টারিং লজিক (সার্চ কুয়েরি + চিপস ফিল্টার)
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final studentName = (data['studentName'] ?? '').toString().toLowerCase();
                  final studentId = (data['studentId'] ?? '').toString().toLowerCase();
                  final attendance = data['attendanceStatus'] ?? 'Present';
                  final feeStatus = data['feeStatus'] ?? 'NO';

                  // ১. সার্চ ম্যাচিং
                  final matchesSearch = studentName.contains(_searchQuery) || studentId.contains(_searchQuery);

                  // ২. ক্যাটাগরি চিপস ম্যাচিং
                  bool matchesFilter = true;
                  if (_selectedFilter == 'Present') matchesFilter = attendance == 'Present';
                  if (_selectedFilter == 'Absent') matchesFilter = attendance == 'Absent';
                  if (_selectedFilter == 'Fees Pending') matchesFilter = feeStatus == 'NO';

                  return matchesSearch && matchesFilter;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text('No matching records found.', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    final attendance = data['attendanceStatus'] ?? 'Present';
                    final feeStatus = data['feeStatus'] ?? 'NO';
                    final dateTimestamp = data['date'] as Timestamp?;
                    
                    String formattedDate = '';
                    if (dateTimestamp != null) {
                      final date = dateTimestamp.toDate();
                      formattedDate = '${date.day}/${date.month}/${date.year}';
                    }

                    // কালার স্কিম কনফিগারেশন
                    Color attendanceColor = Colors.green;
                    if (attendance == 'Absent') attendanceColor = Colors.red;
                    if (attendance == 'Late') attendanceColor = Colors.orange;
                    if (attendance == 'Holiday') attendanceColor = Colors.blue;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(14)),
                                child: Icon(Icons.person_rounded, color: Colors.blue[800], size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['studentName'] ?? 'Student',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B1B1B)),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      data['studentId'] ?? 'No ID',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500], fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                              ),
                              if (formattedDate.isNotEmpty)
                                Text(
                                  formattedDate,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
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
                              Expanded(
                                child: Text(
                                  'Subject: ${data['subject'] ?? 'N/A'}',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Text(
                                'Status: $attendance',
                                style: TextStyle(color: attendanceColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Month: ${data['month'] ?? 'N/A'}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              Text(
                                'Fee: ${feeStatus == 'YES' ? 'Received' : 'Pending'}',
                                style: TextStyle(
                                  color: feeStatus == 'YES' ? Colors.green[700] : Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10.0),
                            child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          ),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[800],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              onPressed: () => _showUpdateDialog(data),
                              icon: const Icon(Icons.update_rounded, size: 18),
                              label: const Text('UPDATE ENTRY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
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
