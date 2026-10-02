import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/ai_knowledge.dart';
import 'teacher_service.dart';

enum AppLanguage { bengali, hindi, english }

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
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(AiKnowledge.systemInstruction),
      generationConfig: GenerationConfig(
        maxOutputTokens: 500,
        temperature: 0.7,
      ),
    );
    _chatSession = _model.startChat();
  }

  // বাংলা, হিন্দি এবং ইংরেজি ভাষা ডিটেক্ট করার লজিক
  AppLanguage _detectLanguage(String text) {
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      return AppLanguage.hindi; // দেবনাগরী হরফ (হিন্দি)
    } else if (RegExp(r'[\u0980-\u09FF]').hasMatch(text)) {
      return AppLanguage.bengali; // বাংলা হরফ
    }
    return AppLanguage.english; // ডিফল্ট ইংরেজি
  }

  // ভাষা অনুযায়ী কাস্টম মেসেজ রিটার্ন করার হেলপার
  String _getErrorMessage({
    required AppLanguage lang,
    required String bn,
    required String hi,
    required String en,
  }) {
    switch (lang) {
      case AppLanguage.bengali:
        return bn;
      case AppLanguage.hindi:
        return hi;
      case AppLanguage.english:
        return en;
    }
  }

  Future<String?> sendChatMessage(String prompt) async {
    final AppLanguage language = _detectLanguage(prompt);

    if (_apiKey.isEmpty) {
      return _getErrorMessage(
        lang: language,
        bn: "FYBTT AI সার্ভিস কনফিগারেশনে সমস্যা রয়েছে। অনুগ্রহ করে অ্যাপ অ্যাডমিনের সাথে যোগাযোগ করুন।",
        hi: "FYBTT AI सेवा कॉन्फ़िगरेशन में समस्या है। कृपया ऐप एडमिन से संपर्क करें।",
        en: "FYBTT AI service configuration issue. Please contact the app admin.",
      );
    }

    _chatSession ??= _model.startChat();

    String finalPrompt = prompt;

    final lowerPrompt = prompt.toLowerCase();
    
    // বাংলা, ইংরেজি এবং হিন্দিতে টিচার সার্চ কিওয়ার্ড চেক
    if (lowerPrompt.contains('teacher') ||
        lowerPrompt.contains('tuition') ||
        lowerPrompt.contains('find') ||
        lowerPrompt.contains('need') ||
        lowerPrompt.contains('শিক্ষক') ||
        lowerPrompt.contains('টিচার') ||
        lowerPrompt.contains('টিউশন') ||
        lowerPrompt.contains('शिक्षक') ||
        lowerPrompt.contains('टीचर') ||
        lowerPrompt.contains('ट्यूशन') ||
        lowerPrompt.contains('चाहिए')) {
      List<Map<String, dynamic>> realTeachers = await _teacherService.searchTeachers();
      if (realTeachers.isNotEmpty) {
        finalPrompt = '''
User Question: $prompt

Real Teacher Data from Database:
$realTeachers

Instruction: Present the relevant teachers from the above real database data to answer the user's request accurately. Respond in the exact language used by the user. If no matching teacher is found in the provided data, clearly state that no teacher is currently available for this requirement.
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

        if ((e.message.contains("503") || e.message.contains("UNAVAILABLE") || e.message.contains("429")) && attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt + 1));
          continue;
        }

        if (e.message.contains("503") || e.message.contains("UNAVAILABLE") || e.message.contains("429")) {
          return _getErrorMessage(
            lang: language,
            bn: "FYBTT AI সার্ভার এই মুহূর্তে কিছুটা ব্যস্ত রয়েছে। অনুগ্রহ করে কয়েক সেকেন্ড পর আবার চেষ্টা করুন।",
            hi: "FYBTT AI सर्वर इस समय व्यस्त है। कृपया कुछ सेकंड बाद पुनः प्रयास करें।",
            en: "FYBTT AI server is currently experiencing high demand. Please try again in a few seconds.",
          );
        }

        return _getErrorMessage(
          lang: language,
          bn: "FYBTT AI সিস্টেমে একটি সাময়িক সমস্যা হয়েছে। অনুগ্রহ করে পরে আবার চেষ্টা করুন।",
          hi: "FYBTT AI सिस्टम में एक अस्थायी समस्या आई है। कृपया बाद में पुनः प्रयास करें।",
          en: "A temporary issue occurred with FYBTT AI service. Please try again later.",
        );
      } catch (e) {
        debugPrint("Gemini Error: $e");
        return _getErrorMessage(
          lang: language,
          bn: "আপনার ইন্টারনেট সংযোগটি পরীক্ষা করুন এবং আবার চেষ্টা করুন।",
          hi: "कृपया अपना इंटरनेट कनेक्शन जांचें और पुनः प्रयास करें।",
          en: "Please check your internet connection and try again.",
        );
      }
    }

    return _getErrorMessage(
      lang: language,
      bn: "FYBTT AI সার্ভার সাড়া দিচ্ছে না। অনুগ্রহ করে একটু পর চেষ্টা করুন।",
      hi: "FYBTT AI सर्वर कोई प्रतिक्रिया नहीं दे रहा है। कृपया कुछ देर बाद प्रयास करें।",
      en: "FYBTT AI server is not responding. Please try again shortly.",
    );
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
