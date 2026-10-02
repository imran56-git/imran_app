import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/ai_knowledge.dart';
import 'teacher_service.dart';

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  late final GenerativeModel _model;
  ChatSession? _chatSession;
  final TeacherService _teacherService = TeacherService();

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
    if (_apiKey.isEmpty) {
      return "GEMINI_API_KEY not found. Please check your secret key setup.";
    }

    _chatSession ??= _model.startChat();

    int maxRetries = 2;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await _chatSession!.sendMessage(Content.text(prompt));
        return response.text;
      } on GenerativeAIException catch (e) {
        debugPrint("Gemini Exception (Attempt ${attempt + 1}): $e");

        if ((e.message.contains("503") || e.message.contains("UNAVAILABLE")) && attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt + 1));
          continue;
        }

        if (e.message.contains("503") || e.message.contains("UNAVAILABLE")) {
          return "Google AI server is currently experiencing high demand. Please try again in a few seconds.";
        }

        return "An issue occurred with the AI service. Please try again later.";
      } catch (e) {
        debugPrint("Gemini Error: $e");
        return "Please check your internet connection and try again.";
      }
    }
    return "Server is not responding. Please try again.";
  }

  Future<List<Map<String, dynamic>>> fetchTeachersForAi({
    String? subject,
    String? location,
    String? className,
  }) async {
    return await _teacherService.searchTeachers(
      subject: subject,
      location: location,
      className: className,
    );
  }

  void resetChat() {
    _chatSession = _model.startChat();
  }
}
