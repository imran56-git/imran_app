import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditUpiScreen extends StatefulWidget {
  final String teacherId;

  const EditUpiScreen({super.key, required this.teacherId});

  @override
  State<EditUpiScreen> createState() => _EditUpiScreenState();
}

class _EditUpiScreenState extends State<EditUpiScreen> {
  final TextEditingController _upiController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // সুনির্দিষ্ট ইনপুট ভ্যালিডেশনের জন্য গ্লোবাল কি
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUpi();
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUpi() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(widget.teacherId)
          .get();

      if (doc.exists && mounted) {
        final currentUpi = doc.data()?['upiId'] ?? '';
        setState(() {
          _upiController.text = currentUpi;
        });
      }
    } catch (e) {
      debugPrint("Error loading UPI: $e");
    }
  }

  Future<void> _saveUpi() async {
    // ফর্ম ভ্যালিডেশন ট্রিগার
    if (!_formKey.currentState!.validate()) return;

    final newUpi = _upiController.text.trim();

    // কিবোর্ড অটো-হাইড সেফটি নেট
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      // প্রোডাকশন লেডি আর্কিটেকচারাল সেফটি সেট অপশন
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(widget.teacherId)
          .set({'upiId': newUpi}, SetOptions(merge: true));

      if (!mounted) return;

      _showSnackBar("UPI ID saved successfully!", isError: false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showSnackBar("Failed to update UPI ID. Please try again.");
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // আপনার অ্যাপের স্ট্যান্ডার্ড বিজি সিঙ্ক
      appBar: AppBar(
        title: const Text(
          "Setup Payments (UPI)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E4C7A), // ডিপ ব্লু ফিন্যান্স থিম
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                
                // প্রিমিয়াম ইনফো কার্ড (লেনদেনের সেফটি গাইডলাইন)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E4C7A).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E4C7A).withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, color: Color(0xFF1E4C7A), size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Secure Tuition Payments",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1B1B1B)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Students will pay your monthly fees directly to this UPI address. Please make sure it is perfectly accurate.",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                const Text(
                  "Your UPI Address",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B1B1B)),
                ),
                const SizedBox(height: 10),

                // মডার্ন মেটেরিয়াল ৩ টেক্সটফর্মফিল্ড
                TextFormField(
                  controller: _upiController,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Enter UPI ID",
                    labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                    hintText: "username@okaxis, mobile@ybl etc.",
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF1E4C7A)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF1E4C7A), width: 1.8),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  
                  // প্রোডাকশন গ্রেড UPI Regex ভ্যালিডেটর ইঞ্জিন (বাগ ফিক্স)
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "UPI ID cannot be empty.";
                    }
                    // স্ট্যান্ডার্ড ইউনিভার্সাল UPI ফরম্যাট Regex ম্যাচিং
                    final upiRegex = RegExp(r'^[\w\.\-_]{3,256}@[a-zA-Z]{2,64}$');
                    if (!upiRegex.hasMatch(value.trim())) {
                      return "Please enter a valid UPI ID (e.g., name@okaxis).";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // অ্যানিমেটেড প্রফেশনাল সাবমিট বাটন
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1E4C7A),
                            strokeWidth: 3.5,
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _saveUpi,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E4C7A),
                            foregroundColor: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "SAVE UPI ID",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
