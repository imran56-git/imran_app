import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      appBar: AppBar(
        title: const Text("Fee Reminders"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: studentsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No students found."));
          }

          final List<QueryDocumentSnapshot> students = snapshot.data!.docs;

          return ListView.builder(
            itemCount: students.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final studentDoc = students[index];
              final Map<String, dynamic> student = studentDoc.data() as Map<String, dynamic>;
              final String studentId = studentDoc.id;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    student['name'] ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Amount: ₹${student['feeAmount'] ?? 0}\nReminder Day: ${student['reminderDay'] ?? 'Not Set'}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.payment, color: Colors.green),
                        onPressed: () {
                          // Navigate to AddPaymentScreen
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.history, color: Colors.blue),
                        onPressed: () {
                          // Navigate to PaymentHistoryScreen
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () {
                          // Show SetReminderDialog
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
