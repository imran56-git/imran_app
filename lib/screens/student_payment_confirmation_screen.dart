import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentPaymentConfirmationScreen extends StatefulWidget {
  final String teacherId;

  const StudentPaymentConfirmationScreen({super.key, required this.teacherId});

  @override
  State<StudentPaymentConfirmationScreen> createState() => _StudentPaymentConfirmationScreenState();
}

class _StudentPaymentConfirmationScreenState extends State<StudentPaymentConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _transactionIdController = TextEditingController();

  bool _isLoading = false;

  Future<void> _submitPayment() async {
    // 1. Basic Validation
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User authentication failed.");

      final String studentId = user.uid;

      // 2. Data Preparation
      final Map<String, dynamic> paymentData = {
        'teacherId': widget.teacherId,
        'studentId': studentId,
        'amount': double.tryParse(_amountController.text.trim()) ?? 0.0,
        'subject': _subjectController.text.trim(),
        'month': _monthController.text.trim(),
        'transactionId': _transactionIdController.text.trim(),
        'status': 'pending', // Waiting for teacher approval
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 3. Database Operation
      await FirebaseFirestore.instance.collection('payments').add(paymentData);

      // 4. Success Handling with Mounted Check
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payment confirmation sent to teacher."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Submission failed: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _subjectController.dispose();
    _monthController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Confirm Payment", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Submit Payment Details",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                "Provide accurate info for teacher verification.",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 25),
              
              _buildTextField(
                controller: _amountController,
                label: "Amount Paid (₹)",
                icon: Icons.account_balance_wallet_outlined,
                type: TextInputType.number,
                formatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _subjectController,
                label: "Subject Name",
                icon: Icons.auto_stories_outlined,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _monthController,
                label: "Month / Purpose",
                icon: Icons.event_note_outlined,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _transactionIdController,
                label: "Transaction ID / Reference",
                icon: Icons.password_outlined,
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("SEND TO TEACHER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? formatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      inputFormatters: formatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.indigo[400]),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.indigo[700]!, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      validator: (value) => value == null || value.trim().isEmpty ? "Field required" : null,
    );
  }
}
