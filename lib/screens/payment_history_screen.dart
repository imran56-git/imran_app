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

  // ফায়ারবেস টাইমস্ট্যাম্পকে রিডেবল ডেট ফরম্যাটে রূপান্তরের হেল্পার
  String _formatFirebaseDate(dynamic firebaseDate) {
    if (firebaseDate == null) return "Unknown Date";
    try {
      if (firebaseDate is Timestamp) {
        DateTime dateTime = firebaseDate.toDate();
        return "${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}";
      }
      return firebaseDate.toString();
    } catch (e) {
      return "Format Error";
    }
  }

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
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text("Payment History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: paymentsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _errorState();
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Colors.blue[800]));
          }

          final List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
          if (docs.isEmpty) return _emptyState();

          // রিয়েল-টাইম টোটাল অ্যামাউন্ট ক্যালকুলেশন
          double totalAmount = docs.fold(0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            return sum + (double.tryParse(data['amount'].toString()) ?? 0);
          });

          return Column(
            children: [
              // প্রিমিয়াম সামারি হেডার প্যানেল
              _buildSummaryHeader(totalAmount, docs.length),

              // ট্রানজেকশন লিস্ট
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index * 50)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 15),
                          child: child,
                        ),
                      ),
                      child: _buildAdvancedPaymentCard(data, context),
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

  // --- মেটেরিয়াল ৩ সামারি হেডার ---
  Widget _buildSummaryHeader(double total, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.blue[800],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue[800]!.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            "Total Fees Received".toUpperCase(), 
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            "₹${total.toStringAsFixed(0)}", 
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.black, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Total Transactions: $count", 
              style: const TextStyle(color: Colors.white90, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // --- প্রফেশনাল পেমেন্ট কার্ড ডিজাইন ---
  Widget _buildAdvancedPaymentCard(Map<String, dynamic> data, BuildContext context) {
    String method = data['method']?.toString().toUpperCase() ?? 'OTHER';
    String formattedDate = _formatFirebaseDate(data['date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getMethodColor(method).withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_getMethodIcon(method), color: _getMethodColor(method), size: 24),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "₹${data['amount']}", 
              style: const TextStyle(fontWeight: FontWeight.black, fontSize: 19, color: Color(0xFF1B1B1B)),
            ),
            // সাকসেস ক্যাপসুল ব্যাজ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "SUCCESS", 
                style: TextStyle(color: Color(0xFF065F46), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.payment_rounded, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text("Via $method", style: TextStyle(fontSize: 13, color: Colors.slate[600], fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text("Date: $formattedDate", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.share_outlined, color: Colors.blue[800], size: 22),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Downloading PDF Receipt..."),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _getMethodIcon(String method) {
    if (method.contains('CASH')) return Icons.money_rounded;
    if (method.contains('UPI') || method.contains('ONLINE')) return Icons.account_balance_wallet_rounded;
    return Icons.credit_card_rounded;
  }

  Color _getMethodColor(String method) {
    if (method.contains('CASH')) return Colors.orange[700]!;
    return Colors.blue[700]!;
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 42),
              const SizedBox(height: 12),
              Text("Error fetching payment data.", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ],
          ),
        ),
      );

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: Colors.grey[400], size: 48),
              const SizedBox(height: 14),
              Text("No payments recorded yet.", style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
}
