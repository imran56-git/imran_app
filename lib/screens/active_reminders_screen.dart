import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveRemindersScreen extends StatelessWidget {
  final String teacherId;

  const ActiveRemindersScreen({
    super.key,
    required this.teacherId,
  });

  void _showDeleteDialog(BuildContext context, String docId, String studentName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Reminder',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
        ),
        content: Text('Are you sure you want to cancel the monthly recurring reminder for $studentName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('payment_reminders')
                  .doc(docId)
                  .delete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final TextEditingController amountController =
        TextEditingController(text: ((data['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0));

    int selectedDay = (data['dayOfMonth'] as num?)?.toInt() ?? 10;
    int hour = (data['reminderHour'] as num?)?.toInt() ?? 16;
    int minute = (data['reminderMinute'] as num?)?.toInt() ?? 0;
    TimeOfDay selectedTime = TimeOfDay(hour: hour, minute: minute);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isAm = selectedTime.period == DayPeriod.am;
          final hourDisplay = selectedTime.hourOfPeriod == 0 ? 12 : selectedTime.hourOfPeriod;
          final minuteDisplay = selectedTime.minute.toString().padLeft(2, '0');

          void openTimePicker() {
            int tempHour = selectedTime.hourOfPeriod == 0 ? 12 : selectedTime.hourOfPeriod;
            int tempMinute = selectedTime.minute;
            bool tempIsAm = selectedTime.period == DayPeriod.am;

            final hourCtrl = FixedExtentScrollController(initialItem: tempHour - 1);
            final minuteCtrl = FixedExtentScrollController(initialItem: tempMinute);
            final amPmCtrl = FixedExtentScrollController(initialItem: tempIsAm ? 0 : 1);

            showGeneralDialog(
              context: context,
              barrierDismissible: true,
              barrierLabel: '',
              transitionDuration: const Duration(milliseconds: 250),
              pageBuilder: (_, __, ___) => const SizedBox(),
              transitionBuilder: (context, anim, _, child) {
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                      CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                    ),
                    child: AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: const Center(
                        child: Text(
                          'Select Reminder Time',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1E3A8A)),
                        ),
                      ),
                      content: SizedBox(
                        height: 170,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 55,
                              child: CupertinoPicker(
                                scrollController: hourCtrl,
                                itemExtent: 40,
                                onSelectedItemChanged: (idx) {
                                  HapticFeedback.selectionClick();
                                  tempHour = idx + 1;
                                },
                                children: List.generate(
                                  12,
                                  (i) => Center(
                                    child: Text(
                                      '${i + 1}'.padLeft(2, '0'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            SizedBox(
                              width: 55,
                              child: CupertinoPicker(
                                scrollController: minuteCtrl,
                                itemExtent: 40,
                                onSelectedItemChanged: (idx) {
                                  HapticFeedback.selectionClick();
                                  tempMinute = idx;
                                },
                                children: List.generate(
                                  60,
                                  (i) => Center(
                                    child: Text(
                                      '$i'.padLeft(2, '0'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 65,
                              child: CupertinoPicker(
                                scrollController: amPmCtrl,
                                itemExtent: 40,
                                onSelectedItemChanged: (idx) {
                                  HapticFeedback.selectionClick();
                                  tempIsAm = idx == 0;
                                },
                                children: const [
                                  Center(child: Text('AM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16))),
                                  Center(child: Text('PM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 16))),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            int finalHour = tempHour;
                            if (tempIsAm && finalHour == 12) finalHour = 0;
                            if (!tempIsAm && finalHour != 12) finalHour += 12;

                            setSheetState(() {
                              selectedTime = TimeOfDay(hour: finalHour, minute: tempMinute);
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Edit Reminder: ${data['studentName'] ?? 'Student'}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Monthly Fee (₹)',
                      prefixIcon: Icon(Icons.currency_rupee_rounded, color: Colors.blue[800]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedDay,
                              isExpanded: true,
                              items: List.generate(
                                31,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text('Day ${i + 1} of month', style: const TextStyle(fontSize: 13)),
                                ),
                              ),
                              onChanged: (val) {
                                if (val != null) setSheetState(() => selectedDay = val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: openTimePicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('$hourDisplay:$minuteDisplay', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 4),
                                    Text(
                                      isAm ? 'AM' : 'PM',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        color: isAm ? Colors.blue[800] : Colors.indigo[800],
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
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final double newAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                        await FirebaseFirestore.instance.collection('payment_reminders').doc(doc.id).update({
                          'amount': newAmount,
                          'dayOfMonth': selectedDay,
                          'reminderHour': selectedTime.hour,
                          'reminderMinute': selectedTime.minute,
                          'lastUpdated': FieldValue.serverTimestamp(),
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStudentAvatar(String studentId, String studentName) {
    if (studentId.isEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.blue.shade100,
        child: Text(
          studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900], fontSize: 17),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('students').doc(studentId).get(),
      builder: (context, snapshot) {
        String? imageUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          imageUrl = data?['profileImageUrl'] ?? data?['profilePic'] ?? data?['imageUrl'];
        }

        if (imageUrl != null && imageUrl.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.network(
              imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallbackAvatar(studentName),
            ),
          );
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(studentId).get(),
          builder: (context, userSnapshot) {
            String? userImageUrl;
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
              userImageUrl = userData?['profileImageUrl'] ?? userData?['profilePic'] ?? userData?['photoUrl'];
            }

            if (userImageUrl != null && userImageUrl.isNotEmpty) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  userImageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackAvatar(studentName),
                ),
              );
            }

            return _fallbackAvatar(studentName);
          },
        );
      },
    );
  }

  Widget _fallbackAvatar(String name) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.indigo.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'S',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Active Reminders', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 19)),
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
        stream: FirebaseFirestore.instance
            .collection('payment_reminders')
            .where('teacherId', isEqualTo: teacherId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_rounded, size: 68, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No active recurring reminders',
                    style: TextStyle(fontSize: 17, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reminders you schedule will repeat every month.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
           }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final String studentName = data['studentName'] ?? 'Student';
              final String studentId = data['studentId'] ?? '';
              final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
              final int day = (data['dayOfMonth'] as num?)?.toInt() ?? 10;
              final int hour = (data['reminderHour'] as num?)?.toInt() ?? 16;
              final int minute = (data['reminderMinute'] as num?)?.toInt() ?? 0;

              final period = hour >= 12 ? 'PM' : 'AM';
              final hour12 = hour % 12 == 0 ? 12 : hour % 12;
              final timeFormatted = '$hour12:${minute.toString().padLeft(2, '0')} $period';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildStudentAvatar(studentId, studentName),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      studentName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFA7F3D0)),
                                    ),
                                    child: const Text(
                                      'Recurring',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                studentId,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'monospace'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showEditSheet(context, doc);
                            } else if (val == 'delete') {
                              _showDeleteDialog(context, doc.id, studentName);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_rounded, size: 18, color: Color(0xFF2563EB)),
                                  SizedBox(width: 10),
                                  Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                  SizedBox(width: 10),
                                  Text('Delete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Text(
                            '₹${amount.toStringAsFixed(0)} / month',
                            style: TextStyle(fontSize: 13, color: Colors.blue[900], fontWeight: FontWeight.bold),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.event_repeat_rounded, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 5),
                            Text(
                              'Day $day  •  $timeFormatted',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
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
    );
  }
}