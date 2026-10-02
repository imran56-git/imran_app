import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/ai_knowledge.dart';
import 'teacher_service.dart';

class GeminiService {
  // 🔴 ১. যদি আপনি String.fromEnvironment ব্যবহার করেন এবং রান টাইমে পাস না করেন, তবে এটি খালি থাকবে
  // পরীক্ষা করার জন্য প্রয়োজন হলে 'AIzaSy...' সরাসরি এই ভ্যারিয়েবলে বসিয়ে দেখতে পারেন।
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  late final GenerativeModel _model;
  ChatSession? _chatSession;
  final TeacherService _teacherService = TeacherService();

  GeminiService() {
    _initModel();
  }

  void _initModel() {
    debugPrint("--------------------------------------------------");
    debugPrint("⚙️ [GeminiService] Initializing Model...");
    debugPrint("🔑 Key Length: ${_apiKey.length} characters");

    if (_apiKey.isEmpty) {
      debugPrint("❌ ERROR: API Key is EMPTY! String.fromEnvironment failed or key not set.");
      return;
    }

    try {
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
      debugPrint("✅ [GeminiService] Model & Chat Session initialized successfully.");
    } catch (e, stackTrace) {
      debugPrint("❌ [GeminiService Init Exception]: $e");
      debugPrint("📌 StackTrace:\n$stackTrace");
    }
    debugPrint("--------------------------------------------------");
  }

  Future<String?> sendChatMessage(String prompt) async {
    debugPrint("\n==================================================");
    debugPrint("📩 [Gemini Request Sent]");
    debugPrint("💬 Prompt: $prompt");

    // ১. API Key চেক
    if (_apiKey.isEmpty) {
      const errorStr = "🔴 [ORIGIN ERROR: API KEY MISSING]\n\n"
          "কারণ: GEMINI_API_KEY খালি।\n"
          "সমাধান: lib/services/gemini_service.dart ফাইলে _apiKey-এর জায়গায় সরাসরি আপনার Gemini API Key বসান।";
      debugPrint("❌ $errorStr");
      return errorStr;
    }

    _chatSession ??= _model.startChat();

    String finalPrompt = prompt;
    final lowerPrompt = prompt.toLowerCase();

    // ২. টিচার সার্ভিস ব্যাকএন্ড চেক
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
      try {
        debugPrint("🔍 Searching database for teachers...");
        List<Map<String, dynamic>> realTeachers = await _teacherService.searchTeachers();
        debugPrint("📊 Teachers found in DB: ${realTeachers.length}");
        
        if (realTeachers.isNotEmpty) {
          finalPrompt = '''
User Question: $prompt

Real Teacher Data from Database:
$realTeachers

Instruction: Present the relevant teachers from the above real database data to answer the user's request accurately. Respond in the exact language used by the user. If no matching teacher is found in the provided data, clearly state that no teacher is currently available for this requirement.
''';
        }
      } catch (teacherErr) {
        debugPrint("⚠️ [TeacherService Error]: $teacherErr");
      }
    }

    // ৩. Gemini API রিকোয়েস্ট ট্রাই-ক্যাচ (অরিজিনাল এরর বের করার অংশ)
    try {
      debugPrint("🚀 Calling Gemini API (gemini-1.5-flash)...");
      final response = await _chatSession!.sendMessage(Content.text(finalPrompt));
      debugPrint("✅ [Gemini Response Received Successfully]");
      debugPrint("==================================================\n");
      return response.text;

    } on GenerativeAIException catch (e, stackTrace) {
      // 🔴 Gemini SDK নির্দিষ্ট এরর (যেমন: 400 Bad Request, Invalid API Key, Quota Exceeded)
      debugPrint("❌ [ORIGIN: GenerativeAIException Triggered]");
      debugPrint("📝 Message: ${e.message}");
      debugPrint("📌 Full Trace:\n$stackTrace");
      debugPrint("==================================================\n");

      return "🔴 [ORIGIN ERROR: Gemini API Exception]\n\n"
          "এরর কোড / ডিটেইলস:\n${e.message}\n\n"
          "💡 সম্ভাব্য কারণ:\n"
          "১. API Key টি অবৈধ বা মেয়াদোত্তীর্ণ।\n"
          "২. Google AI Studio-র কোটা শেষ।\n"
          "৩. gemini-1.5-flash মডেল সাপোর্ট করছে না।";

    } catch (e, stackTrace) {
      // 🔴 ইন্টারনেট সমস্যা বা অন্য কোনো জেনেরিক এরর
      debugPrint("❌ [ORIGIN: General Network/System Error]");
      debugPrint("📝 Exception Type: ${e.runtimeType}");
      debugPrint("📝 Details: $e");
      debugPrint("📌 Full Trace:\n$stackTrace");
      debugPrint("==================================================\n");

      return "🔴 [ORIGIN ERROR: ${e.runtimeType}]\n\n"
          "ডিটেইলস:\n$e\n\n"
          "💡 (ইন্টারনেট কানেকশন, সকেট সংযোগ বা অন্য কোনো ক্র্যাশ হতে পারে)";
    }
  }

  void resetChat() {
    if (_apiKey.isNotEmpty) {
      _chatSession = _model.startChat();
    }
  }
}
