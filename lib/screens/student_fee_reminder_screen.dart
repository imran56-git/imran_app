import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_history_screen.dart';

class StudentFeeReminderScreen extends StatelessWidget {
  final String teacherId;

  const StudentFeeReminderScreen({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    final CollectionReference studentsRef = FirebaseFirestore.instance
        .collection('teachers')
        .doc(teacherId)
        .collection('students');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Student Fee Manager", 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: studentsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error: Connection Failed"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final List<QueryDocumentSnapshot> students = snapshot.data!.docs;

          return ListView.builder(
            itemCount: students.length,
            padding: const EdgeInsets.all(14),
            itemBuilder: (context, index) {
              final Map<String, dynamic> student = students[index].data() as Map<String, dynamic>;
              final String studentId = students[index].id;
              
              // logic for status (simple example)
              bool isOverdue = student['isDue'] ?? false; 

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.all(15),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.teal.withOpacity(0.1),
                        child: Text(
                          (student['name'] ?? 'S')[0].toUpperCase(),
                          style: TextStyle(color: Colors.teal[900], fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              student['name'] ?? 'Unknown Student',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                          ),
                          _buildStatusBadge(isOverdue),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          "Fee: ₹${student['feeAmount'] ?? 0} • Reminder: ${student['reminderDay'] ?? 'Not Set'}",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _actionIcon(Icons.add_task_rounded, "Payment", Colors.green, () {
                            _showQuickAddPayment(context, studentId, student['name']);
                          }),
                          _actionIcon(Icons.history_rounded, "History", Colors.blue, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PaymentHistoryScreen(
                                  teacherId: teacherId,
                                  studentId: studentId,
                                ),
                              ),
                            );
                          }),
                          _actionIcon(Icons.edit_calendar_rounded, "Edit", Colors.orange, () {
                            // Logic to edit reminder
                          }),
                        ],
                      ),
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

  Widget _buildStatusBadge(bool isDue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDue ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDue ? Colors.red : Colors.green, width: 0.5),
      ),
      child: Text(
        isDue ? "DUE" : "PAID",
        style: TextStyle(color: isDue ? Colors.red : Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showQuickAddPayment(BuildContext context, String id, String? name) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Add Payment for $name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            const TextField(decoration: InputDecoration(labelText: "Amount", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: const Text("Confirm Payment"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No students found. Add your first student!", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
