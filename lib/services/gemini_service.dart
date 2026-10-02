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
      generationConfig: GenerationConfig(
        maxOutputTokens: 500,
        temperature: 0.7,
      ),
    );
    _chatSession = _model.startChat();
  }

  Future<String?> sendChatMessage(String prompt) async {
    if (_apiKey.isEmpty) {
      return "GEMINI_API_KEY not found. Please check your secret key setup.";
    }

    _chatSession ??= _model.startChat();

    String finalPrompt = prompt;

    final lowerPrompt = prompt.toLowerCase();
    if (lowerPrompt.contains('teacher') ||
        lowerPrompt.contains('tuition') ||
        lowerPrompt.contains('find') ||
        lowerPrompt.contains('need')) {
      List<Map<String, dynamic>> realTeachers = await _teacherService.searchTeachers();
      if (realTeachers.isNotEmpty) {
        finalPrompt = '''
User Question: $prompt

Real Teacher Data from Database:
$realTeachers

Instruction: Present the relevant teachers from the above real database data to answer the user's request accurately. If no matching teacher is found in the provided data, clearly state that no teacher is currently available for this requirement.
''';
      }
    }

    int maxRetries = 2;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await _chatSession!.sendMessage(Content.text(finalPrompt));
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
