import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditUpiScreen extends StatefulWidget {
  final String teacherId;

  EditUpiScreen({required this.teacherId});

  @override
  _EditUpiScreenState createState() => _EditUpiScreenState();
}

class _EditUpiScreenState extends State<EditUpiScreen> {
  final TextEditingController _upiController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUpi();
  }

  void _loadCurrentUpi() async {
    final doc = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(widget.teacherId)
        .get();
    final currentUpi = doc.data()?['upiId'] ?? '';
    _upiController.text = currentUpi;
  }

  void _saveUpi() async {
    setState(() {
      _loading = true;
    });

    await FirebaseFirestore.instance
        .collection('teachers')
        .doc(widget.teacherId)
        .update({'upiId': _upiController.text});

    setState(() {
      _loading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("UPI ID saved successfully!")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Edit UPI ID")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _upiController,
              decoration: InputDecoration(
                labelText: "Enter your UPI ID",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            _loading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveUpi,
                    child: Text("Save UPI ID"),
                  ),
          ],
        ),
      ),
    );
  }
}