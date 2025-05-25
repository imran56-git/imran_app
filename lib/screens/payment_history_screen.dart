import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentHistoryScreen extends StatelessWidget {
  final String teacherId;
  final String studentId;

  PaymentHistoryScreen({required this.teacherId, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final paymentsRef = FirebaseFirestore.instance
        .collection('teachers')
        .doc(teacherId)
        .collection('students')
        .doc(studentId)
        .collection('payments')
        .orderBy('date', descending: true);

    return Scaffold(
      appBar: AppBar(title: Text("Payment History")),
      body: StreamBuilder<QuerySnapshot>(
        stream: paymentsRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final payments = snapshot.data!.docs;

          if (payments.isEmpty) {
            return Center(child: Text("No payments found."));
          }

          return ListView.builder(
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              return ListTile(
                leading: Icon(Icons.currency_rupee),
                title: Text("₹${payment['amount']}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Method: ${payment['method']}"),
                    if (payment['note'] != '') Text("Note: ${payment['note']}"),
                    Text("Date: ${payment['date']} ${payment['time']}"),
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