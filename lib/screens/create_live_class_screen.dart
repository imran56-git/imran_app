import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class LiveClassScreen extends StatefulWidget {
  final String channelName; // Unique Group or Class ID
  final String userName;

  const LiveClassScreen({
    super.key, 
    required this.channelName, 
    required this.userName
  });

  @override
  State<LiveClassScreen> createState() => _LiveClassScreenState();
}

class _LiveClassScreenState extends State<LiveClassScreen> {
  late RtcEngine _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isVideoOff = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  // --- Initialize Agora Engine ---
  Future<void> _initAgora() async {
    // Request Microhpone and Camera Permissions
    await [Permission.microphone, Permission.camera].request();

    // Create the engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RfcEngineContext(
      appId: "YOUR_AGORA_APP_ID_HERE", // Replace with your Agora App ID
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Local user ${connection.localUid} joined");
          setState(() => _localUserJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Remote user $remoteUid joined");
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("Remote user $remoteUid left channel");
          setState(() => _remoteUid = null);
        },
      ),
    );

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    await _engine.startPreview();

    await _engine.joinChannel(
      token: "YOUR_TEMP_TOKEN_HERE", // Use token for production security
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  // --- Toggle Mic (Mute/Unmute) ---
  void _onToggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteLocalAudioStream(_isMuted);
  }

  // --- Toggle Video (Camera On/Off) ---
  void _onToggleVideo() {
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
    _engine.enableLocalVideo(!_isVideoOff);
  }

  // --- Switch Front/Back Camera ---
  void _onSwitchCamera() {
    _engine.switchCamera();
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: _remoteVideo()), // Main remote video (Teacher)
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 120,
              height: 180,
              child: Center(
                child: _localUserJoined && !_isVideoOff
                    ? AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _engine,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      )
                    : Container(color: Colors.grey[900], child: const Icon(Icons.videocam_off, color: Colors.white)),
              ),
            ),
          ),
          _buildToolbar(), // Call Controls (Mute, Camera, Leave)
        ],
      ),
    );
  }

  // Display Remote User (Teacher's View)
  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    } else {
      return const Text(
        'Waiting for other participants...',
        style: TextStyle(color: Colors.white),
      );
    }
  }

  // WhatsApp/Zoom style toolbar
  Widget _buildToolbar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RawMaterialButton(
              onPressed: _onToggleMute,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12.0),
              fillColor: _isMuted ? Colors.redAccent : Colors.white,
              child: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: _isMuted ? Colors.white : Colors.blueAccent, size: 20.0),
            ),
            RawMaterialButton(
              onPressed: () {
                _engine.leaveChannel();
                Navigator.pop(context);
              },
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(15.0),
              fillColor: Colors.redAccent,
              child: const Icon(Icons.call_end, color: Colors.white, size: 35.0),
            ),
            RawMaterialButton(
              onPressed: _onToggleVideo,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12.0),
              fillColor: _isVideoOff ? Colors.redAccent : Colors.white,
              child: Icon(_isVideoOff ? Icons.videocam_off : Icons.videocam, color: _isVideoOff ? Colors.white : Colors.blueAccent, size: 20.0),
            ),
            RawMaterialButton(
              onPressed: _onSwitchCamera,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12.0),
              fillColor: Colors.white,
              child: const Icon(Icons.switch_camera, color: Colors.blueAccent, size: 20.0),
            ),
          ],
        ),
      ),
    );
  }
}
