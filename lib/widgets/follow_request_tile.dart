import 'package:flutter/material.dart';
import '../models/follow_model.dart';
import '../services/follow_service.dart';
import '../screens/student_profile_screen.dart'; // প্রয়োজন অনুযায়ী প্রোফাইল স্ক্রিনের ইম্পোর্ট পাথ ঠিক করে নেবেন

class FollowRequestTile extends StatelessWidget {
  final FollowModel followRequest;

  const FollowRequestTile({
    super.key,
    required this.followRequest,
  });

  void _navigateToStudentProfile(BuildContext context) {
    if (followRequest.studentId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentProfileScreen(
          currentUserId: followRequest.studentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FollowService followService = FollowService();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF1E4C7A).withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Student Profile Photo (Tappable)
          GestureDetector(
            onTap: () => _navigateToStudentProfile(context),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF1E4C7A).withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFEDF4FA),
                backgroundImage: followRequest.studentPhoto.isNotEmpty
                    ? NetworkImage(followRequest.studentPhoto) as ImageProvider
                    : const AssetImage('assets/images/default_avatar.png'),
                child: followRequest.studentPhoto.isEmpty
                    ? const Icon(Icons.person, color: Color(0xFF1E4C7A))
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Student Name & Custom Request Subtitle (Tappable Name)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _navigateToStudentProfile(context),
                  child: Text(
                    followRequest.studentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'wants to become your student',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Reject Button
          InkWell(
            onTap: () async {
              await followService.rejectRequest(
                followRequest.teacherId,
                followRequest.studentId,
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Accept Button
          InkWell(
            onTap: () async {
              await followService.acceptRequest(
                followRequest.teacherId,
                followRequest.studentId,
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF2E7D32),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
