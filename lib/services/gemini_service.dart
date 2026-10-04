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

  void _initModel() {
    if (_apiKey.isEmpty) return;

    try {
      _model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: _apiKey,
        systemInstruction: Content.system(
          '${AiKnowledge.systemInstruction}\n'
          'Behavior Guidelines:\n'
          '1. You are the official assistant for FYBTT (Find Your Best Teacher Today).\n'
          '2. If the user asks educational, study-related, science, or general academic questions (e.g. Newton\'s laws, Math, English), answer them concisely, accurately, and helpfully as an FYBTT study assistant.\n'
          '3. Keep responses fast, polite, and direct without unnecessary delay.',
        ),
        generationConfig: GenerationConfig(
          maxOutputTokens: 800,
          temperature: 0.5,
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
          return '⚠️ FYBTT অ্যাসিস্ট্যান্ট কনফিগারেশনে সমস্যা হয়েছে। অনুগ্রহ করে সেটিংস চেক করুন।';
        } else if (lang == 'hi') {
          return '⚠️ FYBTT सहायक कॉन्फ़िगरेशन में समस्या है। कृपया सेटिंग्स जांचें।';
        }
        return '⚠️ FYBTT Assistant configuration error. Please check your setup.';

      case 'busy_error':
        if (lang == 'bn') {
          return '✨ FYBTT সহকারী এই মুহূর্তে প্রচুর রিকোয়েস্ট প্রসেস করছে। অনুগ্রহ করে কয়েক সেকেন্ড পর আবার চেষ্টা করুন।';
        } else if (lang == 'hi') {
          return '✨ FYBTT सहायक इस समय अत्यधिक व्यस्त है। कृपया कुछ सेकंड बाद पुनः प्रयास करें।';
        }
        return '✨ FYBTT Assistant is handling high traffic right now. Please try again in a few seconds.';

      case 'api_error':
        if (lang == 'bn') {
          return '⚠️ FYBTT সহকারী উত্তরটি প্রস্তুত করতে পারেনি। অনুগ্রহ করে আবার প্রশ্নটি করুন।';
        } else if (lang == 'hi') {
          return '⚠️ FYBTT सहायक उत्तर तैयार नहीं कर सका। कृपया पुनः प्रयास करें।';
        }
        return '⚠️ FYBTT Assistant could not generate a response. Please try again.';

      case 'network_error':
      default:
        if (lang == 'bn') {
          return '📡 FYBTT সার্ভারের সাথে সংযোগ বিচ্ছিন্ন হয়েছে। অনুগ্রহ করে আপনার ইন্টারনেট সংযোগটি চেক করুন।';
        } else if (lang == 'hi') {
          return '📡 FYBTT सर्वर से कनेक्शन कट गया है। कृपया अपना इंटरनेट जांचें।';
        }
        return '📡 Unable to connect to FYBTT servers. Please check your internet connection.';
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

    int retryCount = 0;
    const int maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        final response = await _chatSession!
            .sendMessage(Content.text(prompt))
            .timeout(const Duration(seconds: 15));

        if (response.text != null && response.text!.isNotEmpty) {
          return response.text;
        } else {
          return _getErrorMessage('api_error', lang);
        }
      } on GenerativeAIException catch (e) {
        if (e.message.contains('503') || e.message.contains('demand')) {
          retryCount++;
          if (retryCount <= maxRetries) {
            await Future.delayed(Duration(milliseconds: 1000 * retryCount));
            continue;
          }
          return _getErrorMessage('busy_error', lang);
        }
        return _getErrorMessage('api_error', lang);
      } on TimeoutException {
        retryCount++;
        if (retryCount <= maxRetries) {
          await Future.delayed(const Duration(milliseconds: 800));
          continue;
        }
        return _getErrorMessage('busy_error', lang);
      } catch (_) {
        return _getErrorMessage('network_error', lang);
      }
    }

    return _getErrorMessage('busy_error', lang);
  }

  void resetChat() {
    if (_model != null) {
      _chatSession = _model!.startChat();
    }
  }
}
