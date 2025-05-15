import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class VoiceMessageHandler {
  FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  String? _recordedFilePath;

  Future<void> initRecorder() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }
    await _recorder.openRecorder();
    _isRecorderInitialized = true;
  }

  Future<void> startRecording() async {
    if (!_isRecorderInitialized) await initRecorder();

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/${const Uuid().v4()}.aac';
    _recordedFilePath = filePath;

    await _recorder.startRecorder(toFile: filePath);
  }

  Future<String?> stopAndUploadRecording(String chatId) async {
    if (!_isRecorderInitialized) return null;

    final path = await _recorder.stopRecorder();
    if (path == null) return null;

    final file = File(path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';

    final ref = FirebaseStorage.instance
        .ref()
        .child('voice_messages')
        .child(chatId)
        .child(fileName);

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    return url;
  }

  void dispose() {
    _recorder.closeRecorder();
  }
}