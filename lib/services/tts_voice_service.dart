import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused }

class TtsVoiceService {
  static final TtsVoiceService _instance = TtsVoiceService._internal();
  factory TtsVoiceService() => _instance;
  TtsVoiceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  TtsState _ttsState = TtsState.stopped;

  VoidCallback? onStart;
  VoidCallback? onComplete;
  VoidCallback? onError;

  bool get isPlaying => _ttsState == TtsState.playing;

  Future<void> initTts() async {
    await _flutterTts.awaitSynthCompletion(true);

    if (Platform.isAndroid) {
      try {
        final engines = await _flutterTts.getEngines;
        if (engines is List) {
          for (var engine in engines) {
            if (engine.toString().contains('com.google.android.tts')) {
              await _flutterTts.setEngine('com.google.android.tts');
              break;
            }
          }
        }
      } catch (_) {}
    }

    _flutterTts.setStartHandler(() {
      _ttsState = TtsState.playing;
      onStart?.call();
    });

    _flutterTts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
      onComplete?.call();
    });

    _flutterTts.setErrorHandler((msg) {
      _ttsState = TtsState.stopped;
      onError?.call();
    });

    _flutterTts.setCancelHandler(() {
      _ttsState = TtsState.stopped;
    });

    _flutterTts.setPauseHandler(() {
      _ttsState = TtsState.paused;
    });
  }

  bool _isBengali(String text) {
    final bengaliRegex = RegExp(r'[\u0980-\u09FF]');
    return bengaliRegex.hasMatch(text);
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'#+'), '')
        .replaceAll(RegExp(r'`+'), '')
        .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '')
        .trim();
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    final cleanedText = _cleanText(text);

    if (_isBengali(cleanedText)) {
      await _flutterTts.setLanguage('bn-IN');
      await _flutterTts.setSpeechRate(0.46);
      await _flutterTts.setPitch(1.0);
    } else {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
    }

    await _flutterTts.setVolume(1.0);
    await _flutterTts.speak(cleanedText);
  }

  Future<void> stop() async {
    if (_ttsState == TtsState.playing || _ttsState == TtsState.paused) {
      await _flutterTts.stop();
      _ttsState = TtsState.stopped;
    }
  }

  Future<void> pause() async {
    if (_ttsState == TtsState.playing) {
      await _flutterTts.pause();
      _ttsState = TtsState.paused;
    }
  }

  void dispose() {
    _flutterTts.stop();
  }
}
