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

  @override
  void initState() {
    super.initState();
    _setupLiveClassEngine();
  }

  @override
  void dispose() {
    // ফিক্সড: মেমোরি লিক এবং ব্যাকগ্রাউন্ড ডাটা ড্রেনিং রুখতে লিসেনার ক্লিনআপ (#14)
    _classStreamSubscription?.cancel();
    super.dispose();
  }

  void _setupLiveClassEngine() {
    // ১. প্রথমে Jitsi কনফারেন্স লঞ্চ করা হবে
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchJitsiMeeting();
    });

    // ২. ফিক্সড: ব্যাকগ্রাউন্ড ফায়ারবেস লিসেনার এবং অটো-টার্মিনেশন রুল (#13, #14)
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

      // টিচার যদি ক্লাস শেষ করে দেন, তবে স্টুডেন্টদের স্ক্রিন অটো-ক্লোজ হবে
      if (!isLive && !widget.isTeacher) {
        _forceLeaveOnClassEnd();
      }
    });
  }

  void _launchJitsiMeeting() async {
    try {
      var options = JitsiMeetConferenceOptions(
        room: widget.roomId,
        configOverrides: {
          "startWithAudioMuted": !widget.isTeacher, // টিচার বাদে স্টুডেন্টরা ডিফল্ট মিউট থাকবে
          "startWithVideoMuted": false,
          "subject": widget.subjectTitle,
          "prejoin.enabled": false,
        },
        featureFlags: {
          "unsecureRoomNameWarning.enabled": false,
          "welcomePage.enabled": false,
          "prejoin.enabled": false,
          "recording.enabled": false,
          "liveStreaming.enabled": false,
          "toolbox.alwaysVisible": true,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: widget.userName,
          email: "${widget.userId}@app.com",
        ),
      );

      await _jitsiMeetPlugin.join(options);
      if (mounted) {
        setState(() => _isConferenceJoined = true);
      }
    } catch (e) {
      debugPrint("Jitsi Launch Error: $e");
    }
  }

  // ফিক্সড: ক্লাস এন্ড ট্রিগার এবং জেসচার সিকিউরিটি পপ (#13)
  void _forceLeaveOnClassEnd() async {
    _classStreamSubscription?.cancel();
    try {
      await _jitsiMeetPlugin.hangUp(); // Jitsi SDK সেশন ক্লোজ করা হচ্ছে
    } catch (e) {
      debugPrint("Jitsi Hangup Error: $e");
    }
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
    _classStreamSubscription?.cancel();
    try {
      await _jitsiMeetPlugin.hangUp();
    } catch (e) {
      debugPrint("Jitsi Manual Hangup Error: $e");
    }

    if (widget.isTeacher) {
      // টিচার লিভ নিলে পুরো সেশন অ্যান্ড হবে ফায়ারবেসে
      await _liveClassService.endLiveClass(widget.roomId);
    } else {
      // স্টুডেন্ট লিভ নিলে শুধু পার্টিসিপেন্ট লিস্ট থেকে রিমুভ হবে
      await _liveClassService.leaveParticipant(widget.roomId, widget.userId);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  // ফিক্সড: হ্যান্ড রেইজ সিঙ্ক মেকানিজম (#11)
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
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        title: Text(widget.subjectTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF1F2937),
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
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator(color: Colors.blue));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
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
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.video_call_rounded, 
                          size: 72, 
                          color: widget.isTeacher ? Colors.redAccent : Colors.blueAccent
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isConferenceJoined ? 'Jitsi Room Active' : 'Connecting to Jitsi...',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Room Code: ${widget.roomId}',
                        style: const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              
              // ফিক্সড: স্মার্ট রিয়েল-টাইম ইন্টারঅ্যাকশন ড্যাশবোর্ড বার (#11, #12)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1F2937),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // স্টুডেন্টদের জন্য হ্যান্ড রেইজ বাটন এবং টিচারদের জন্য ট্র্যাকিং টেক্সট
                        if (!widget.isTeacher) ...[
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isAmIRaised ? Colors.amber[700] : Colors.grey[800],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () => _toggleHandRaise(isAmIRaised, handRaisedUsers),
                            icon: Icon(isAmIRaised ? Icons.front_hand : Icons.front_hand_outlined, size: 18),
                            label: Text(isAmIRaised ? 'Lower Hand' : 'Raise Hand', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              const Icon(Icons.front_hand, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${handRaisedUsers.length} Student(s) Raised Hand',
                                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                        
                        // সেশন টার্মিনেশন বাটন
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            elevation: 0,
                          ),
                          onPressed: _leaveConference,
                          icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                          label: Text(
                            widget.isTeacher ? 'END FOR ALL' : 'LEAVE',
                            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ],
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
