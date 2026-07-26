import 'package:flutter/material.dart';
import '../services/follow_service.dart';

class FollowButton extends StatelessWidget {
  final String teacherId;
  final String studentId;
  final String teacherName;
  final String studentName;
  final String teacherPhoto;
  final String studentPhoto;

  const FollowButton({
    super.key,
    required this.teacherId,
    required this.studentId,
    required this.teacherName,
    required this.studentName,
    required this.teacherPhoto,
    required this.studentPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final FollowService followService = FollowService();

    return StreamBuilder<String>(
      stream: followService.streamFollowStatus(teacherId, studentId),
      builder: (context, snapshot) {
        final status = snapshot.data ?? 'none';

        String buttonText = 'Follow';
        Color buttonColor = Colors.blue;
        Color textColor = Colors.white;
        VoidCallback? onPressed;

        if (status == 'pending') {
          buttonText = 'Requested';
          buttonColor = Colors.orange;
          onPressed = () async {
            await followService.cancelRequest(teacherId, studentId);
          };
        } else if (status == 'accepted') {
          buttonText = 'Following';
          buttonColor = Colors.grey.shade300;
          textColor = Colors.black87;
          onPressed = () async {
            await followService.unfollowTeacher(teacherId, studentId);
          };
        } else if (status == 'rejected') {
          buttonText = 'Follow Again';
          buttonColor = Colors.blue;
          onPressed = () async {
            await followService.sendFollowRequest(
              teacherId: teacherId,
              studentId: studentId,
              teacherName: teacherName,
              studentName: studentName,
              teacherPhoto: teacherPhoto,
              studentPhoto: studentPhoto,
            );
          };
        } else {
          buttonText = 'Follow';
          buttonColor = Colors.blue;
          onPressed = () async {
            await followService.sendFollowRequest(
              teacherId: teacherId,
              studentId: studentId,
              teacherName: teacherName,
              studentName: studentName,
              teacherPhoto: teacherPhoto,
              studentPhoto: studentPhoto,
            );
          };
        }

        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: textColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            buttonText,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        );
      },
    );
  }
}
