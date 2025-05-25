import 'package:flutter/material.dart';
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final studentId = FirebaseAuth.instance.currentUser!.uid;

    final paymentData = {
      'teacherId': widget.teacherId,
      'studentId': studentId,
      'amount': _amountController.text.trim(),
      'subject': _subjectController.text.trim(),
      'month': _monthController.text.trim(),
      'transactionId': _transactionIdController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('payments').add(paymentData);

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Payment confirmation submitted")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Confirmation")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: "Amount Paid (₹)"),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? "Enter amount" : null,
              ),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: "Subject"),
                validator: (value) => value!.isEmpty ? "Enter subject" : null,
              ),
              TextFormField(
                controller: _monthController,
                decoration: const InputDecoration(labelText: "Month / Purpose"),
                validator: (value) => value!.isEmpty ? "Enter purpose" : null,
              ),
              TextFormField(
                controller: _transactionIdController,
                decoration: const InputDecoration(labelText: "Transaction ID"),
                validator: (value) => value!.isEmpty ? "Enter transaction ID" : null,
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submitPayment,
                      child: const Text("Submit Confirmation"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}