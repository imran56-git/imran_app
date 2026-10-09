import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _jitsiMeetPlugin = JitsiMeet();

  StreamSubscription<DocumentSnapshot>? _classStreamSubscription;
  bool _isConferenceJoined = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _setupLiveClassEngine();
  }

  @override
  void dispose() {
    _classStreamSubscription?.cancel();
    super.dispose();
  }

  void _setupLiveClassEngine() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchJitsiMeeting();
    });

    _classStreamSubscription = _firestore
        .collection('live_classes')
        .doc(widget.roomId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        _forceLeaveOnClassEnd();
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>?;
      final bool isLive = data?['isLive'] ?? false;

      if (!isLive && !widget.isTeacher) {
        _forceLeaveOnClassEnd();
      }
    });
  }

  void _launchJitsiMeeting() async {
    try {
      final sanitizedRoom = widget.roomId
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .toLowerCase();

      final options = JitsiMeetConferenceOptions(
        serverURL: "https://meet.ffmuc.net",
        room: "fybtt_live_$sanitizedRoom",
        configOverrides: {
          "startWithAudioMuted": !widget.isTeacher,
          "startWithVideoMuted": false,
          "subject": widget.subjectTitle,
          "prejoinPageEnabled": false,
          "prejoinConfig": {"enabled": false},
          "enableInsecureRoomNameWarning": false,
          "lobby": {"enabled": false},
          "enableLobbyChat": false,
          "disableDeepLinking": true,
          "requireDisplayName": false,
          "hideConferenceTimer": false,
          "enableWelcomePage": false,
        },
        featureFlags: {
          FeatureFlags.preJoinPageEnabled: false,
          FeatureFlags.unsafeRoomWarningEnabled: false,
          FeatureFlags.lobbyModeEnabled: false,
          FeatureFlags.welcomePageEnabled: false,
          FeatureFlags.securityOptionEnabled: false,
          FeatureFlags.meetingPasswordEnabled: false,
          FeatureFlags.recordingEnabled: false,
          FeatureFlags.liveStreamingEnabled: false,
          FeatureFlags.serverUrlChangeEnabled: false,
          FeatureFlags.toolboxAlwaysVisible: true,
          FeatureFlags.addPeopleEnabled: false,
          FeatureFlags.inviteEnabled: false,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: widget.userName.isNotEmpty ? widget.userName : (widget.isTeacher ? 'Teacher' : 'Student'),
          email: "${widget.userId}@fybtt.edu",
        ),
      );

      final listener = JitsiMeetEventListener(
        conferenceJoined: (url) {
          if (mounted) {
            setState(() => _isConferenceJoined = true);
          }
        },
        conferenceTerminated: (url, error) {
          _leaveConference();
        },
      );

      await _jitsiMeetPlugin.join(options, listener);
    } catch (e) {
      debugPrint("Jitsi Launch Error: $e");
    }
  }

  void _forceLeaveOnClassEnd() async {
    if (_isClosing) return;
    _isClosing = true;

    _classStreamSubscription?.cancel();
    try {
      await _jitsiMeetPlugin.hangUp();
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The live class session has ended.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _leaveConference() async {
    if (_isClosing) return;
    _isClosing = true;

    _classStreamSubscription?.cancel();
    try {
      await _jitsiMeetPlugin.hangUp();
    } catch (_) {}

    if (widget.isTeacher) {
      await _liveClassService.endLiveClass(widget.roomId);
    } else {
      await _liveClassService.leaveParticipant(widget.roomId, widget.userId);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleHandRaise(bool isRaised, List currentHandRaisedUsers) async {
    List updatedList = List.from(currentHandRaisedUsers);
    if (isRaised) {
      updatedList.remove(widget.userId);
    } else {
      updatedList.add(widget.userId);
    }
    await _firestore.collection('live_classes').doc(widget.roomId).update({
      'handRaisedUsers': updatedList,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          widget.subjectTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: _leaveConference,
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('live_classes').doc(widget.roomId).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.hasData && snapshot.data!.exists
              ? snapshot.data!.data() as Map<String, dynamic>
              : <String, dynamic>{};

          final List handRaisedUsers = data['handRaisedUsers'] ?? [];
          final bool isAmIRaised = handRaisedUsers.contains(widget.userId);

          return Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          color: (widget.isTeacher ? Colors.redAccent : Colors.blueAccent).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isTeacher ? Icons.sensors_rounded : Icons.videocam_rounded,
                          size: 68,
                          color: widget.isTeacher ? Colors.redAccent : Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _isConferenceJoined ? 'Classroom Session Active' : 'Entering Live Classroom...',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Room ID: ${widget.roomId}',
                        style: const TextStyle(color: Colors.white60, fontSize: 13, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!widget.isTeacher)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAmIRaised ? Colors.amber[700] : const Color(0xFF334155),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          elevation: 0,
                        ),
                        onPressed: () => _toggleHandRaise(isAmIRaised, handRaisedUsers),
                        icon: Icon(isAmIRaised ? Icons.front_hand : Icons.front_hand_outlined, size: 18),
                        label: Text(
                          isAmIRaised ? 'Lower Hand' : 'Raise Hand',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.front_hand, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${handRaisedUsers.length} Hand Raised',
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: _leaveConference,
                      icon: const Icon(Icons.call_end_rounded, size: 18),
                      label: Text(
                        widget.isTeacher ? 'END CLASS' : 'LEAVE',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}