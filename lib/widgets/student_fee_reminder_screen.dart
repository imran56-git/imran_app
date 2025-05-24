import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SetReminderDialog extends StatefulWidget {
  final String teacherId;
  final String studentId;
  final DocumentSnapshot existingData;

  SetReminderDialog({
    required this.teacherId,
    required this.studentId,
    required this.existingData,
  });

  @override
  _SetReminderDialogState createState() => _SetReminderDialogState();
}

class _SetReminderDialogState extends State<SetReminderDialog> {
  late TextEditingController amountController;
  late TextEditingController dayController;
  late TimeOfDay selectedTime;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(text: widget.existingData['feeAmount'].toString());
    dayController = TextEditingController(text: widget.existingData['reminderDay'].toString());
    selectedTime = TimeOfDay(
      hour: int.parse(widget.existingData['reminderTime'].split(":")[0]),
      minute: int.parse(widget.existingData['reminderTime'].split(":")[1]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Set Fee Reminder"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amountController,
            decoration: InputDecoration(labelText: "Fee Amount"),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: dayController,
            decoration: InputDecoration(labelText: "Reminder Day (1-31)"),
            keyboardType: TextInputType.number,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Time: ${selectedTime.format(context)}"),
              TextButton(
                child: Text("Pick Time"),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (picked != null) setState(() => selectedTime = picked);
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          child: Text("Save"),
          onPressed: () async {
            await FirebaseFirestore.instance
                .collection('teachers')
                .doc(widget.teacherId)
                .collection('students')
                .doc(widget.studentId)
                .update({
              'feeAmount': int.parse(amountController.text),
              'reminderDay': int.parse(dayController.text),
              'reminderTime': "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
            });
            Navigator.pop(context);
          },
        )
      ],
    );
  }
}