import 'package:flutter/material.dart';
import '../services/follow_service.dart';

class FollowButton extends StatefulWidget {
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
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  final FollowService _followService = FollowService();
  bool _isLoading = false;

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check for valid IDs to prevent silent crashes
    if (widget.teacherId.isEmpty || widget.studentId.isEmpty) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: () => _showSnackBar('User identity missing. Unable to follow.'),
        child: const Text('Follow Teacher', style: TextStyle(color: Colors.white)),
      );
    }

    return StreamBuilder<String>(
      stream: _followService.streamFollowStatus(widget.teacherId, widget.studentId),
      builder: (context, snapshot) {
        final status = snapshot.data ?? 'none';

        String buttonText = 'Follow Teacher';
        Color buttonColor = const Color(0xFF1E63B5);
        Color textColor = Colors.white;
        IconData buttonIcon = Icons.person_add_rounded;

        if (status == 'pending') {
          buttonText = 'Requested';
          buttonColor = Colors.orange.shade700;
          buttonIcon = Icons.access_time_rounded;
        } else if (status == 'accepted') {
          buttonText = 'Following';
          buttonColor = Colors.grey.shade300;
          textColor = Colors.black87;
          buttonIcon = Icons.check_circle_rounded;
        } else if (status == 'rejected') {
          buttonText = 'Follow Again';
          buttonColor = const Color(0xFF1E63B5);
          buttonIcon = Icons.refresh_rounded;
        }

        return ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: textColor,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          icon: _isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              : Icon(buttonIcon, size: 18, color: textColor),
          label: Text(
            buttonText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: textColor,
            ),
          ),
          onPressed: _isLoading
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  try {
                    if (status == 'pending') {
                      await _followService.cancelRequest(widget.teacherId, widget.studentId);
                      _showSnackBar('Follow request cancelled.');
                    } else if (status == 'accepted') {
                      await _followService.unfollowTeacher(widget.teacherId, widget.studentId);
                      _showSnackBar('Unfollowed teacher.');
                    } else {
                      await _followService.sendFollowRequest(
                        teacherId: widget.teacherId,
                        studentId: widget.studentId,
                        teacherName: widget.teacherName,
                        studentName: widget.studentName,
                        teacherPhoto: widget.teacherPhoto,
                        studentPhoto: widget.studentPhoto,
                      );
                      _showSnackBar('Follow request sent successfully!');
                    }
                  } catch (e) {
                    _showSnackBar('Operation failed. Please try again.');
                  } finally {
                    if (mounted) {
                      setState(() => _isLoading = false);
                    }
                  }
                },
        );
      },
    );
  }
}
