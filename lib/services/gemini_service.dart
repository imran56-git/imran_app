import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  late final GenerativeModel _model;

  GeminiService() {
    _initModel();
  }

  void _initModel() {
    _model = GenerativeModel(
      model: 'gemini-3.8-flash', 
      apiKey: _apiKey,
    );
  }

  Future<String?> generateResponse(String prompt) async {
    try {
      if (_apiKey.isEmpty) {
        return "Error: GEMINI_API_KEY is empty! Check GitHub Secret setup.";
      }
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text;
    } catch (e) {
      debugPrint("Gemini AI Error: $e");
      return "Error Details: $e";
    }
  }
}
