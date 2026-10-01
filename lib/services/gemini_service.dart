import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/ai_knowledge.dart';

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  late final GenerativeModel _model;
  ChatSession? _chatSession;

  GeminiService() {
    _initModel();
  }

  void _initModel() {
    _model = GenerativeModel(
      model: 'gemini-3.8-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(AiKnowledge.systemInstruction),
    );
    _chatSession = _model.startChat();
  }

  Future<String?> sendChatMessage(String prompt) async {
    try {
      if (_apiKey.isEmpty) {
        return "Error: GEMINI_API_KEY is empty! Check GitHub Secret setup.";
      }

      _chatSession ??= _model.startChat();

      final response = await _chatSession!.sendMessage(Content.text(prompt));
      return response.text;
    } catch (e) {
      debugPrint("Gemini AI Error: $e");
      return "Error Details: $e";
    }
  }

  void resetChat() {
    _chatSession = _model.startChat();
  }
}
