import 'package:flutter/material.dart';
import '../../models/live_class_model.dart';
import '../../services/live_class_service.dart';
import '../../widgets/success_toast.dart';
import 'live_class_screen.dart';

class JoinLiveScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final bool isTeacher;

  const JoinLiveScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.isTeacher,
  });

  @override
  State<JoinLiveScreen> createState() => _JoinLiveScreenState();
}

class _JoinLiveScreenState extends State<JoinLiveScreen> {
  final LiveClassService _liveClassService = LiveClassService();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  bool _isLoading = false;

  void _handleLiveAction() async {
    final roomId = _roomController.text.trim().toLowerCase();
    final title = _titleController.text.trim();

    if (roomId.isEmpty) return;
    if (widget.isTeacher && title.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      if (widget.isTeacher) {
        final liveClass = LiveClassModel(
          roomId: roomId,
          title: title,
          teacherId: widget.currentUserId,
          teacherName: widget.currentUserName,
          isLive: true,
          createdAt: DateTime.now(),
          isMicMuted: false,
          isCameraOff: false,
          participants: [widget.currentUserId],
          handRaisedUsers: [],
          allowedMicUsers: [widget.currentUserId],
        );

        await _liveClassService.createLiveClass(liveClass);
        if (mounted) {
          SuccessToast.show(context, 'Live Class Created Successfully');
        }
      } else {
        await _liveClassService.joinParticipant(roomId, widget.currentUserId);
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveClassScreen(
              roomId: roomId,
              userId: widget.currentUserId,
              userName: widget.currentUserName,
              isTeacher: widget.isTeacher,
              subjectTitle: widget.isTeacher ? title : 'Live Class Session',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again!')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(widget.isTeacher ? 'Host Live Class' : 'Join Live Class',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isTeacher ? Icons.sensors_rounded : Icons.wifi_tethering_rounded,
                  size: 64,
                  color: widget.isTeacher ? Colors.red : Colors.blue[800],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isTeacher ? 'Start a New Session' : 'Enter Room Code',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                if (widget.isTeacher) ...[
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Class Title / Subject',
                      prefixIcon: const Icon(Icons.title),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _roomController,
                  decoration: InputDecoration(
                    labelText: 'Room Code (Letters or Numbers Only)',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isTeacher ? Colors.red : Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isLoading ? null : _handleLiveAction,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            widget.isTeacher ? 'GO LIVE WITH JITSI' : 'JOIN CLASS NOW',
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
