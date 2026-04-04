import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Date formatting 

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
    final Query paymentsQuery = FirebaseFirestore.instance
        .collection('teachers')
        .doc(teacherId)
        .collection('students')
        .doc(studentId)
        .collection('payments')
        .orderBy('date', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Payment History", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF128C7E), // consistent with your theme
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: paymentsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _errorState();
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
          if (docs.isEmpty) return _emptyState();

          // Advanced: Calculate Total Paid Amount
          double totalAmount = docs.fold(0, (sum, doc) => sum + (double.tryParse(doc['amount'].toString()) ?? 0));

          return Column(
            children: [
              // --- Advanced Summary Card ---
              _buildSummaryHeader(totalAmount, docs.length),
              
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildAdvancedPaymentCard(data, context);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Summary Header (Advanced Feature) ---
  Widget _buildSummaryHeader(double total, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF128C7E),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const Text("Total Fees Received", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 5),
          Text("₹${total.toStringAsFixed(0)}", 
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("Total Transactions: $count", style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  // --- UI Card with advanced styling and Actions ---
  Widget _buildAdvancedPaymentCard(Map<String, dynamic> data, BuildContext context) {
    String method = data['method']?.toString().toUpperCase() ?? 'OTHER';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: _getMethodColor(method).withOpacity(0.1),
          child: Icon(_getMethodIcon(method), color: _getMethodColor(method)),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("₹${data['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Text("SUCCESS", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text("Via $method", style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
            const SizedBox(height: 3),
            Text("Date: ${data['date']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.grey),
          onPressed: () {
            // Future logic: Generate PDF Receipt
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Downloading PDF Receipt...")));
          },
        ),
      ),
    );
  }

  // --- Helper methods for Dynamic UI ---
  IconData _getMethodIcon(String method) {
    if (method.contains('CASH')) return Icons.money;
    if (method.contains('UPI') || method.contains('ONLINE')) return Icons.account_balance_wallet;
    return Icons.payment;
  }

  Color _getMethodColor(String method) {
    if (method.contains('CASH')) return Colors.orange;
    return Colors.blue;
  }

  Widget _errorState() => const Center(child: Text("Error fetching payment data."));
  Widget _emptyState() => const Center(child: Text("No payments recorded yet."));
}
