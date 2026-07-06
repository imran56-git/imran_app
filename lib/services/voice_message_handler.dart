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

  bool get isRecording => _recorder.isRecording;

  Future<void> initRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw RecordingException('Microphone permission denied');
      }

      if (!_isRecorderInitialized) {
        await _recorder.openRecorder();
        _isRecorderInitialized = true;
      }
    } catch (e) {
      throw RecordingException('Initialization failed: $e');
    }
  }

  Future<void> startRecording() async {
    if (!_isRecorderInitialized) {
      await initRecorder();
    }

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

  Future<String?> stopAndUploadRecording(String chatId) async {
    if (!_isRecorderInitialized || !_recorder.isRecording) return null;

    try {
      final path = await _recorder.stopRecorder();
      if (path == null) return null;

      final file = File(path);
      if (!await file.exists()) return null;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('voice_messages')
          .child(chatId)
          .child(fileName);

      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'audio/aac'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      if (await file.exists()) {
        await file.delete();
      }

      return downloadUrl;
    } catch (e) {
      print('Audio Upload Error: $e');
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }

      if (_lastRecordedPath != null) {
        final file = File(_lastRecordedPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      if (_isRecorderInitialized) {
        await _recorder.closeRecorder();
      }
      _isRecorderInitialized = false;
    } catch (_) {}
  }
}

class RecordingException implements Exception {
  final String message;
  RecordingException(this.message);

  @override
  String toString() => 'RecordingException: $message';
}