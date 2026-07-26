import 'package:flutter/material.dart';
import '../models/follow_model.dart';
import '../services/follow_service.dart';

class FollowRequestTile extends StatelessWidget {
  final FollowModel followRequest;

  const FollowRequestTile({
    super.key,
    required this.followRequest,
  });

  @override
  Widget build(BuildContext context) {
    final FollowService followService = FollowService();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Student Profile Photo
          CircleAvatar(
            radius: 24,
            backgroundImage: followRequest.studentPhoto.isNotEmpty
                ? NetworkImage(followRequest.studentPhoto)
                as ImageProvider
                : const AssetImage('assets/images/default_avatar.png'),
          ),
          const SizedBox(width: 12),

          // Student Name & Request Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  followRequest.studentName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Wants to follow you',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Accept & Reject Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reject Button
              IconButton(
                onPressed: () async {
                  await followService.rejectRequest(
                    followRequest.teacherId,
                    followRequest.studentId,
                  );
                },
                icon: const Icon(Icons.close_rounded),
                color: Colors.red,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                ),
              ),
              const SizedBox(width: 8),

              // Accept Button
              IconButton(
                onPressed: () async {
                  await followService.acceptRequest(
                    followRequest.teacherId,
                    followRequest.studentId,
                  );
                },
                icon: const Icon(Icons.check_rounded),
                color: Colors.green,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
