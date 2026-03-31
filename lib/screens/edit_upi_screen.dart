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
    final newUpi = _upiController.text.trim();
    
    if (newUpi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid UPI ID")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(widget.teacherId)
          .update({'upiId': newUpi});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("UPI ID saved successfully!")),
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update UPI ID. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit UPI ID"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            TextFormField(
              controller: _upiController,
              decoration: const InputDecoration(
                labelText: "Enter your UPI ID",
                hintText: "example@okaxis",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveUpi,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Save UPI ID",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
