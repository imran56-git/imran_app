import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class VoiceMessageHandler {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  String? _lastRecordedPath;

  /// Returns true if the recorder is currently active
  bool get isRecording => _recorder.isRecording;

  /// Initializes the audio session and microphone permissions
  Future<void> initRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw RecordingException('Microphone permission denied');
      }

      await _recorder.openRecorder();
      _isRecorderInitialized = true;
    } catch (e) {
      throw RecordingException('Initialization failed: $e');
    }
  }

  /// Starts capturing audio and saves to a temporary local file
  Future<void> startRecording() async {
    if (!_isRecorderInitialized) await initRecorder();
    
    // Prevent starting if already recording
    if (_recorder.isRecording) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = '${const Uuid().v4()}.aac';
      _lastRecordedPath = '${tempDir.path}/$fileName';

      await _recorder.startRecorder(
        toFile: _lastRecordedPath,
        codec: Codec.aacADTS,
      );
    } catch (e) {
      throw RecordingException('Failed to start recording: $e');
    }
  }

  /// Stops recording and uploads to Firebase Storage
  /// Returns the Download URL of the uploaded audio file
  Future<String?> stopAndUploadRecording(String chatId) async {
    if (!_isRecorderInitialized || !_recorder.isRecording) return null;

    try {
      final path = await _recorder.stopRecorder();
      if (path == null) return null;

      final file = File(path);
      if (!await file.exists()) return null;

      // Unique file structure: voice_messages/chatId/timestamp.aac
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('voice_messages')
          .child(chatId)
          .child(fileName);

      // Upload with specific metadata for cross-platform playback
      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'audio/aac'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Cleanup: Delete local temporary file after successful upload
      if (await file.exists()) await file.delete();
      
      return downloadUrl;
    } catch (e) {
      print('Audio Upload Error: $e');
      return null;
    }
  }

  /// Discards the current recording without uploading
  Future<void> cancelRecording() async {
    if (_recorder.isRecording) {
      await _recorder.stopRecorder();
      if (_lastRecordedPath != null) {
        final file = File(_lastRecordedPath!);
        if (await file.exists()) await file.delete();
      }
    }
  }

  /// Closes the recorder session to free up system resources
  void dispose() {
    if (_isRecorderInitialized) {
      _recorder.closeRecorder();
    }
  }
}

// Custom Exception for better error tracking
class RecordingException implements Exception {
  final String message;
  RecordingException(this.message);
  @override
  String toString() => 'RecordingException: $message';
}
