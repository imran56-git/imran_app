import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class InvitationListScreen extends StatefulWidget {
  final String currentUserId;

  const InvitationListScreen({super.key, required this.currentUserId});

  @override
  State<InvitationListScreen> createState() => _InvitationListScreenState();
}

class _InvitationListScreenState extends State<InvitationListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Advanced Transactional Logic to Accept Invitation ---
  Future<void> _acceptInvitation(String groupId, String inviteDocId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference groupRef = _firestore.collection('groups').doc(groupId);
        DocumentReference inviteRef = _firestore
            .collection('users')
            .doc(widget.currentUserId)
            .collection('group_invites')
            .doc(inviteDocId);

        // 1. Add user to group members list
        transaction.update(groupRef, {
          'members': FieldValue.arrayUnion([widget.currentUserId])
        });

        // 2. Delete the invitation after acceptance
        transaction.delete(inviteRef);
      });

      _showSnackBar("Successfully joined the group!");
    } catch (e) {
      _showSnackBar("Failed to join group: $e");
    }
  }

  // --- Logic to Reject/Delete Invitation ---
  Future<void> _rejectInvitation(String inviteDocId) async {
    try {
      await _firestore
          .collection('users')
          .doc(widget.currentUserId)
          .collection('group_invites')
          .doc(inviteDocId)
          .delete();
      _showSnackBar("Invitation declined.");
    } catch (e) {
      _showSnackBar("Error: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Group Invitations",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(widget.currentUserId)
            .collection('group_invites')
            .orderBy('sentAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF128C7E)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final invitations = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: invitations.length,
            itemBuilder: (context, index) {
              var invite = invitations[index].data() as Map<String, dynamic>;
              String inviteId = invitations[index].id;
              String groupId = invite['groupId'];
              Timestamp? sentAt = invite['sentAt'] as Timestamp?;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFE7FFDB),
                          child: Icon(Icons.group_add, color: Color(0xFF128C7E)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invite['groupName'] ?? "New Group",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                "Invited by Teacher", // You can fetch actual teacher name if needed
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (sentAt != null)
                          Text(
                            DateFormat('dd MMM').format(sentAt.toDate()),
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "You have been invited to join this group. Would you like to accept?",
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _rejectInvitation(inviteId),
                            child: const Text("Decline", style: TextStyle(color: Colors.red)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF128C7E),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _acceptInvitation(groupId, inviteId),
                            child: const Text("Accept", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mail_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "No pending invitations",
            style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
