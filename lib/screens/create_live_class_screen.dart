import 'package:flutter/material.dart';
import 'package:jitsi_meet_wrapper/jitsi_meet_wrapper.dart';
import 'package:uuid/uuid.dart';

class CreateLiveClassScreen extends StatefulWidget {
  const CreateLiveClassScreen({super.key});

  @override
  State<CreateLiveClassScreen> createState() => _CreateLiveClassScreenState();
}

class _CreateLiveClassScreenState extends State<CreateLiveClassScreen> {
  final TextEditingController _topicController = TextEditingController();
  bool isAudioMuted = false;
  bool isVideoMuted = false;
  String? generatedRoomCode;

  void startMeeting() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a class topic')),
      );
      return;
    }

    final roomName = const Uuid().v4().substring(0, 8);
    setState(() => generatedRoomCode = roomName);

    final options = JitsiMeetingOptions(roomName: roomName)
      ..subject = topic
      ..userDisplayName = "Teacher"
      ..userEmail = "teacher@example.com"
      ..audioMuted = isAudioMuted
      ..videoMuted = isVideoMuted;

    await JitsiMeetWrapper.joinMeeting(options: options);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Live Class')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Live Class Setup",
              style: theme.textTheme.headline6?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: "Class Topic",
                hintText: "e.g. Class 10 - Science Doubt Clearance",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text("Mute Audio"),
              value: isAudioMuted,
              onChanged: (val) => setState(() => isAudioMuted = val),
              secondary: const Icon(Icons.mic_off),
            ),
            SwitchListTile(
              title: const Text("Mute Video"),
              value: isVideoMuted,
              onChanged: (val) => setState(() => isVideoMuted = val),
              secondary: const Icon(Icons.videocam_off),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: startMeeting,
              icon: const Icon(Icons.video_call),
              label: const Text("Start Live Class"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            if (generatedRoomCode != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  "Room Code: $generatedRoomCode",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}