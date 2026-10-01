import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  late final GenerativeModel _model;

  GeminiService() {
    _initModel();
  }

  void _initModel() {
    if (_apiKey.isEmpty) {
      debugPrint("Warning: GEMINI_API_KEY is missing!");
    }
    _model = GenerativeModel(
      model: 'gemini-3.8-flash',
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
