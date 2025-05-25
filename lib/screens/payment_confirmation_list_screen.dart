import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PaymentConfirmationListScreen extends StatelessWidget {
  final String teacherId;

  const PaymentConfirmationListScreen({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment Confirmations"),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('payments')
            .where('teacherId', isEqualTo: teacherId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No payment confirmations found."));
          }

          final payments = snapshot.data!.docs;

          return ListView.builder(
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final data = payments[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.payment, color: Colors.teal),
                  title: Text("From: ${data['studentName'] ?? 'Unknown'}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Amount: ₹${data['amount'] ?? 'N/A'}"),
                      Text("Subject: ${data['subject'] ?? 'N/A'}"),
                      Text("Transaction ID: ${data['transactionId'] ?? 'N/A'}"),
                      Text(
                        "Date: ${DateTime.fromMillisecondsSinceEpoch(data['timestamp']?.millisecondsSinceEpoch ?? 0).toLocal()}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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