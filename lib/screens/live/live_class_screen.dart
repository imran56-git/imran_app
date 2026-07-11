import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import '../../services/live_class_service.dart';

class LiveClassScreen extends StatefulWidget {
  final String roomId;
  final String userId;
  final String userName;
  final bool isTeacher;
  final String subjectTitle;

  const LiveClassScreen({
    super.key,
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.isTeacher,
    required this.subjectTitle,
  });

  @override
  State<LiveClassScreen> createState() => _LiveClassScreenState();
}

class _LiveClassScreenState extends State<LiveClassScreen> {
  final LiveClassService _liveClassService = LiveClassService();
  final _jitsiMeetPlugin = JitsiMeet();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchJitsiMeeting();
    });
  }

  void _launchJitsiMeeting() async {
    var options = JitsiMeetConferenceOptions(
      room: widget.roomId,
      configOverrides: {
        "startWithAudioMuted": false,
        "startWithVideoMuted": false,
        "subject": widget.subjectTitle,
      },
      featureFlags: {
        "unsecureRoomNameWarning.enabled": false,
        "welcomePage.enabled": false,
        "prejoin.enabled": false,
        "recording.enabled": false,
        "liveStreaming.enabled": false,
      },
      userInfo: JitsiMeetUserInfo(
        displayName: widget.userName,
        email: "${widget.userId}@app.com",
      ),
    );

    await _jitsiMeetPlugin.join(options);
  }

  void _leaveConference() async {
    if (widget.isTeacher) {
      await _liveClassService.endLiveClass(widget.roomId);
    } else {
      await _liveClassService.leaveParticipant(widget.roomId, widget.userId);
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        title: Text(widget.subjectTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _leaveConference,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_call_rounded, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Jitsi Class Session Active',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Room ID: ${widget.roomId}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _leaveConference,
              icon: const Icon(Icons.exit_to_app),
              label: Text(widget.isTeacher ? 'END CLASS FOR ALL' : 'LEAVE CLASS'),
            ),
          ],
        ),
      ),
    );
  }
}
