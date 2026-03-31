import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentHistoryScreen extends StatelessWidget {
  final String teacherId;
  final String studentId;

  const PaymentHistoryScreen({
    super.key, 
    required this.teacherId, 
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    // Ensuring the reference strictly follows your database structure
    final Query paymentsQuery = FirebaseFirestore.instance
        .collection('teachers')
        .doc(teacherId)
        .collection('students')
        .doc(studentId)
        .collection('payments')
        .orderBy('date', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Professional light background
      appBar: AppBar(
        title: const Text(
          "Payment History", 
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: paymentsQuery.snapshots(),
        builder: (context, snapshot) {
          // Error State Handling
          if (snapshot.hasError) {
            return const Center(
              child: Text("Error loading payments. Please check your connection."),
            );
          }

          // Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.indigo));
          }

          final List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

          // Empty State Handling
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    "No payment records found.", 
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          // List Construction
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final Map<String, dynamic> data = docs[index].data() as Map<String, dynamic>;
              
              return _buildPaymentCard(data);
            },
          );
        },
      ),
    );
  }

  // Refined Card Widget for better UI polish
  Widget _buildPaymentCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFFE8EAF6),
                      child: Icon(Icons.currency_rupee, color: Colors.indigo, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "₹${data['amount'] ?? '0'}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 20, 
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                // Dynamic Status Badge (Optional - can be customized)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "PAID",
                    style: TextStyle(color: Colors.green[700], fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 0.8),
            
            // Detail Information Rows
            _buildDetailRow(Icons.payments_outlined, "Method", data['method'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.calendar_today_outlined, "Date & Time", "${data['date'] ?? ''} ${data['time'] ?? ''}"),
            
            // Note Section - only shows if content exists
            if (data['note'] != null && data['note'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  "Note: ${data['note']}",
                  style: const TextStyle(fontSize: 13, color: Colors.black54, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.indigo[300]),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(color: Colors.black54, fontSize: 14)),
        Expanded(
          child: Text(
            value, 
            style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
