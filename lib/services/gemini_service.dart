import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String _apiKey = 'YOUR_GEMINI_API_KEY_HERE';

  late final GenerativeModel _model;

  GeminiService() {
    _initModel();
  }

  void _initModel() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
    );
  }

  Future<String?> generateResponse(String prompt) async {
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text;
    } catch (e) {
      debugPrint("Gemini AI Error: $e");
      return "Sorry, unable to connect to the AI server. Please try again later.";
    }
  }
}
