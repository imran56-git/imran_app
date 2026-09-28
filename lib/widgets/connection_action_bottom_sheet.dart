import 'package:flutter/material.dart';
import '../models/connected_user_model.dart';

class ConnectionActionBottomSheet extends StatelessWidget {
  final ConnectedUserModel user;
  final VoidCallback onMessage;
  final VoidCallback onUnfollowConfirm;

  const ConnectionActionBottomSheet({
    Key? key,
    required this.user,
    required this.onMessage,
    required this.onUnfollowConfirm,
  }) : super(key: key);

  void _showUnfollowDialog(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Unfollow ${user.name}?"),
          content: const Text("You will no longer have this connection."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                onUnfollowConfirm();
              },
              child: const Text("Unfollow", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.blue),
            title: const Text("Message", style: TextStyle(fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              onMessage();
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
            title: const Text("Unfollow", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
            onTap: () => _showUnfollowDialog(context),
          ),
        ],
      ),
    );
  }
}
