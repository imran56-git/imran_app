import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/ai_knowledge.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  static const String _envGeminiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _envGroqKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  String _resolvedGeminiKey = _envGeminiKey.trim();
  String _resolvedGroqKey = _envGroqKey.trim();
  bool _checkedFirestoreKeys = false;

  // Latest active Gemini models (2026 line)
  static const List<String> _geminiModels = [
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-pro',
    'gemini-2.5-pro',
    'gemini-4-argon',
  ];

  // Backup Groq models
  static const List<String> _groqModels = [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
  ];

  int _activeModelIndex = 0;
  bool _isBusy = false;

  final List<Map<String, String>> _conversationHistory = [];

  String _buildSystemInstruction([String? customSystemPrompt]) {
    if (customSystemPrompt != null && customSystemPrompt.trim().isNotEmpty) {
      return customSystemPrompt.trim();
    }
    return '${AiKnowledge.systemInstruction}\n'
        'Behavior Guidelines:\n'
        '1. You are the official AI Assistant for FYBTT (Find Your Best Teacher Today).\n'
        '2. If the user asks educational, study-related, science, math, or general academic questions, answer them concisely, accurately, and helpfully as an FYBTT study assistant.\n'
        '3. Support both English and Bengali naturally based on the user\'s question.\n'
        '4. Keep responses fast, polite, and direct without unnecessary delay.';
  }

  Future<void> _ensureApiKeysLoaded() async {
    if (_resolvedGeminiKey.isNotEmpty && _resolvedGroqKey.isNotEmpty) return;
    if (_checkedFirestoreKeys) return;
    _checkedFirestoreKeys = true;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('ai_keys')
          .get()
          .timeout(const Duration(seconds: 4));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final String fbGemini = (data['geminiApiKey'] ?? '').toString().trim();
        final String fbGroq = (data['groqApiKey'] ?? '').toString().trim();
        if (_resolvedGeminiKey.isEmpty && fbGemini.isNotEmpty) {
          _resolvedGeminiKey = fbGemini;
        }
        if (_resolvedGroqKey.isEmpty && fbGroq.isNotEmpty) {
          _resolvedGroqKey = fbGroq;
        }
      }
    } catch (_) {}
  }

  void _recordTurn(String userPrompt, String aiResponse) {
    _conversationHistory.add({'role': 'user', 'content': userPrompt});
    _conversationHistory.add({'role': 'model', 'content': aiResponse});
    while (_conversationHistory.length > 24) {
      _conversationHistory.removeAt(0);
    }
  }

  Future<String> _callGeminiDirectHttp({
    required String modelName,
    required String prompt,
    String? systemPrompt,
  }) async {
    final String sysInstruction = _buildSystemInstruction(systemPrompt);

    final List<Map<String, dynamic>> contents = [];
    for (final turn in _conversationHistory) {
      final String role = turn['role'] == 'user' ? 'user' : 'model';
      final String text = (turn['content'] ?? '').trim();
      if (text.isEmpty) continue;
      contents.add({
        'role': role,
        'parts': [
          {'text': text}
        ],
      });
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ],
    });

    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$_resolvedGeminiKey',
    );

    final Map<String, dynamic> requestBody = {
      'systemInstruction': {
        'parts': [
          {'text': sysInstruction}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1536,
      },
    };

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini ($modelName) HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final Map<String, dynamic> decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final List<dynamic> candidates =
        (decoded['candidates'] as List<dynamic>?) ?? const [];

    if (candidates.isEmpty) {
      throw Exception('Empty candidates from $modelName');
    }

    final Map<String, dynamic>? content =
        candidates.first['content'] as Map<String, dynamic>?;
    final List<dynamic> parts =
        (content?['parts'] as List<dynamic>?) ?? const [];

    final StringBuffer replyBuffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['thought'] != true && part['text'] != null) {
        replyBuffer.write(part['text'].toString());
      }
    }

    final String finalText = replyBuffer.toString().trim();
    if (finalText.isEmpty) {
      throw Exception('Empty text output from $modelName');
    }

    return finalText;
  }

  Future<String> _callGroqDirectHttp(
    String prompt, {
    String? systemPrompt,
  }) async {
    if (_resolvedGroqKey.isEmpty) {
      throw Exception('GROQ_API_KEY is not configured');
    }

    final String sysInstruction = _buildSystemInstruction(systemPrompt);
    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': sysInstruction},
      ..._conversationHistory.map((turn) => {
            'role': turn['role'] == 'user' ? 'user' : 'assistant',
            'content': turn['content'] ?? '',
          }),
      {'role': 'user', 'content': prompt},
    ];

    Object? lastErr;
    for (final groqModel in _groqModels) {
      try {
        final response = await http
            .post(
              Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_resolvedGroqKey',
              },
              body: jsonEncode({
                'model': groqModel,
                'messages': messages,
                'temperature': 0.7,
                'max_tokens': 1536,
              }),
            )
            .timeout(const Duration(seconds: 22));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data =
              jsonDecode(utf8.decode(response.bodyBytes))
                  as Map<String, dynamic>;
          final List<dynamic> choices =
              (data['choices'] as List<dynamic>?) ?? const [];
          if (choices.isNotEmpty) {
            final msg = choices.first['message'] as Map<String, dynamic>?;
            final String text = (msg?['content'] ?? '').toString().trim();
            if (text.isNotEmpty) {
              _recordTurn(prompt, text);
              return text;
            }
          }
        } else {
          lastErr = 'Groq HTTP ${response.statusCode}';
        }
      } catch (e) {
        lastErr = e;
      }
    }

    throw Exception('Groq fallback error: $lastErr');
  }

  Future<String> generateContent(String prompt, {String? systemPrompt}) async {
    await _ensureApiKeysLoaded();

    Object? lastError;

    if (_resolvedGeminiKey.isNotEmpty) {
      for (int i = 0; i < _geminiModels.length; i++) {
        final int idx = (_activeModelIndex + i) % _geminiModels.length;
        final String modelName = _geminiModels[idx];
        try {
          final String reply = await _callGeminiDirectHttp(
            modelName: modelName,
            prompt: prompt,
            systemPrompt: systemPrompt,
          );
          _activeModelIndex = idx;
          _recordTurn(prompt, reply);
          return reply;
        } catch (e) {
          lastError = e;
          debugPrint('Gemini model $modelName failed: $e');
        }
      }
    }

    if (_resolvedGroqKey.isNotEmpty) {
      try {
        return await _callGroqDirectHttp(prompt, systemPrompt: systemPrompt);
      } catch (e) {
        lastError = e;
        debugPrint('Groq fallback failed: $e');
      }
    }

    throw Exception(lastError ?? 'No AI API key configured.');
  }

  Stream<String> generateContentStream(
    String prompt, {
    String? systemPrompt,
  }) async* {
    if (_isBusy) {
      _isBusy = false;
    }

    _isBusy = true;
    try {
      final String fullResponse = await generateContent(
        prompt,
        systemPrompt: systemPrompt,
      );

      final List<String> words = fullResponse.split(' ');
      final StringBuffer chunk = StringBuffer();

      for (int i = 0; i < words.length; i++) {
        chunk.write(i == words.length - 1 ? words[i] : '${words[i]} ');
        if (i % 4 == 3 || i == words.length - 1) {
          yield chunk.toString();
          chunk.clear();
          await Future.delayed(const Duration(milliseconds: 16));
        }
      }
    } finally {
      _isBusy = false;
    }
  }

  Future<String?> sendChatMessage(String prompt) async {
    try {
      return await generateContent(prompt);
    } catch (e) {
      debugPrint('sendChatMessage error: $e');
      return null;
    }
  }

  void resetChat() {
    _isBusy = false;
    _conversationHistory.clear();
  }
}
