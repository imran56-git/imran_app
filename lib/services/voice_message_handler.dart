import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class VoiceMessageHandler {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;

  /// Initializes the recorder and handles microphone permissions.
  Future<void> initRecorder() async {
    try {
      final micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) {
        return Future.error('Microphone permission not granted');
      }
      
      await _recorder.openRecorder();
      _isRecorderInitialized = true;
    } catch (e) {
      return Future.error('Recorder initialization failed: $e');
    }
  }

  /// Starts the audio recording session with a unique UUID filename.
  Future<void> startRecording() async {
    if (!_isRecorderInitialized) {
      await initRecorder();
    }

    try {
      final tempDir = await getTemporaryDirectory();
      // Maintaining your original UUID logic for unique file paths
      final filePath = '${tempDir.path}/${const Uuid().v4()}.aac';
      
      await _recorder.startRecorder(
        toFile: filePath,
        codec: Codec.aacADTS,
      );
    } catch (e) {
      return Future.error('Recording start failed: $e');
    }
  }

  /// Stops recording and uploads the file to Firebase Storage under the specific Chat ID.
  Future<String?> stopAndUploadRecording(String chatId) async {
    // Safety check to ensure recorder is active before stopping
    if (!_isRecorderInitialized || !_recorder.isRecording) return null;

    try {
      final path = await _recorder.stopRecorder();
      if (path == null) return null;

      final file = File(path);
      if (!await file.exists()) return null;

      // Professional file naming: Timestamp based (from your original code)
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';
      
      final ref = FirebaseStorage.instance
          .ref()
          .child('voice_messages')
          .child(chatId)
          .child(fileName);

      // Uploading with specific audio metadata for better compatibility
      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: 'audio/aac'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      // Internal logging for debugging
      print('Firebase Upload Error: $e');
      return null;
    }
  }

  /// Disposes the recorder to prevent memory leaks.
  void dispose() {
    if (_isRecorderInitialized) {
      _recorder.closeRecorder();
    }
  }
}
