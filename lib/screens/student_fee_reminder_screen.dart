import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_payment_screen.dart';

class StudentFeeReminderScreen extends StatelessWidget {
  final String teacherId;

  StudentFeeReminderScreen({required this.teacherId});

  @override
  Widget build(BuildContext context) {
    final studentsRef = FirebaseFirestore.instance
        .collection('teachers')
        .doc(teacherId)
        .collection('students');

    return Scaffold(
      appBar: AppBar(
        title: Text("Fee Reminders"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: studentsRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();

          final students = snapshot.data!.docs;

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return ListTile(
                title: Text(student['name']),
                subtitle: Text("Amount: ${student['feeAmount']} | Day: ${student['reminderDay']}"),
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(
      icon: Icon(Icons.payment),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddPaymentScreen(
              teacherId: teacherId,
              studentId: student.id,
            ),
          ),
        );
      },
    ),
    IconButton(
      icon: Icon(Icons.edit),
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => SetReminderDialog(
            teacherId: teacherId,
            studentId: student.id,
            existingData: student,
          ),
        );
      },
    ),
  ],
),