import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/ai_knowledge.dart';

class GeminiService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  GenerativeModel? _model;
  ChatSession? _chatSession;

  GeminiService() {
    _initModel();
  }

  void _initModel() {
    if (_apiKey.isEmpty) return;

    try {
      _model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: _apiKey,
        systemInstruction: Content.system(AiKnowledge.systemInstruction),
        generationConfig: GenerationConfig(
          maxOutputTokens: 1000,
          temperature: 0.7,
        ),
      );
      _chatSession = _model!.startChat();
    } catch (_) {}
  }

  String _detectLanguage(String text) {
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(text)) {
      return 'bn';
    } else if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      return 'hi';
    }
    return 'en';
  }

  String _getErrorMessage(String type, String lang) {
    switch (type) {
      case 'missing_key':
        if (lang == 'bn') {
          return 'API কী পাওয়া যায়নি। অনুগ্রহ করে আপনার Gemini API Key সেট করুন।';
        } else if (lang == 'hi') {
          return 'API कुंजी नहीं मिली। कृपया अपनी Gemini API Key सेट करें।';
        }
        return 'API key is missing. Please configure your Gemini API Key.';

      case 'api_error':
        if (lang == 'bn') {
          return 'সার্ভারের সাথে সংযোগে সমস্যা হয়েছে বা API কী অবৈধ। অনুগ্রহ করে কিছুক্ষণ পর আবার চেষ্টা করুন।';
        } else if (lang == 'hi') {
          return 'सर्वर से कनेक्ट करने में समस्या हुई या API कुंजी अमान्य है। कृपया कुछ समय बाद पुनः प्रयास करें।';
        }
        return 'Failed to connect to the AI service or invalid API key. Please try again later.';

      case 'network_error':
      default:
        if (lang == 'bn') {
          return 'ইন্টারনেট সংযোগে সমস্যা হয়েছে। আপনার নেটওয়ার্ক চেক করে আবার চেষ্টা করুন।';
        } else if (lang == 'hi') {
          return 'इंटरनेट कनेक्शन में समस्या है। कृपया अपना नेटवर्क जांचें और पुनः प्रयास करें।';
        }
        return 'Network connection error. Please check your internet connection and try again.';
    }
  }

  Future<String?> sendChatMessage(String prompt) async {
    final lang = _detectLanguage(prompt);

    if (_apiKey.isEmpty) {
      return _getErrorMessage('missing_key', lang);
    }

    if (_model == null || _chatSession == null) {
      _initModel();
      if (_model == null) {
        return _getErrorMessage('api_error', lang);
      }
    }

    try {
      final response = await _chatSession!.sendMessage(Content.text(prompt));
      return response.text;
    } on GenerativeAIException {
      return _getErrorMessage('api_error', lang);
    } catch (_) {
      return _getErrorMessage('network_error', lang);
    }
  }

  void resetChat() {
    if (_model != null) {
      _chatSession = _model!.startChat();
    }
  }
}
