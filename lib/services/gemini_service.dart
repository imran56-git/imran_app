import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/ai_knowledge.dart';

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  GenerativeModel? _model;
  ChatSession? _chatSession;

  GeminiService() {
    _initModel();
  }

  void _initModel({String? customSystemPrompt}) {
    if (_apiKey.isEmpty) return;

    try {
      final sysInstruction = (customSystemPrompt != null && customSystemPrompt.isNotEmpty)
          ? customSystemPrompt
          : '${AiKnowledge.systemInstruction}\n'
              'Behavior Guidelines:\n'
              '1. You are the official assistant for FYBTT (Find Your Best Teacher Today).\n'
              '2. If the user asks educational, study-related, science, or general academic questions, answer them concisely, accurately, and helpfully as an FYBTT study assistant.\n'
              '3. Keep responses fast, polite, and direct without unnecessary delay.';

      _model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: _apiKey,
        systemInstruction: Content.system(sysInstruction),
        generationConfig: GenerationConfig(
          maxOutputTokens: 1024,
          temperature: 0.6,
        ),
      );
      _chatSession = _model!.startChat();
    } catch (_) {}
  }

  Future<String> generateContent(String prompt, {String? systemPrompt}) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is not configured');
    }

    if (_model == null) {
      _initModel(customSystemPrompt: systemPrompt);
      if (_model == null) {
        throw Exception('Failed to initialize Gemini Model');
      }
    }

    try {
      final response = _chatSession != null
          ? await _chatSession!
              .sendMessage(Content.text(prompt))
              .timeout(const Duration(seconds: 12))
          : await _model!
              .generateContent([Content.text(prompt)])
              .timeout(const Duration(seconds: 12));

      final text = response.text;
      if (text != null && text.isNotEmpty) {
        return text.trim();
      }
      throw Exception('Empty response from Gemini');
    } catch (e) {
      resetChat();
      rethrow;
    }
  }

  Stream<String> generateContentStream(String prompt, {String? systemPrompt}) async* {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is not configured');
    }

    if (_model == null) {
      _initModel(customSystemPrompt: systemPrompt);
      if (_model == null) {
        throw Exception('Failed to initialize Gemini Model');
      }
    }

    try {
      final stream = _chatSession != null
          ? _chatSession!
              .sendMessageStream(Content.text(prompt))
              .timeout(const Duration(seconds: 12))
          : _model!
              .generateContentStream([Content.text(prompt)])
              .timeout(const Duration(seconds: 12));

      await for (final response in stream) {
        final text = response.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    } catch (e) {
      resetChat();
      rethrow;
    }
  }

  Future<String?> sendChatMessage(String prompt) async {
    try {
      return await generateContent(prompt);
    } catch (_) {
      return null;
    }
  }

  void resetChat() {
    if (_model != null) {
      _chatSession = _model!.startChat();
    }
  }
}
