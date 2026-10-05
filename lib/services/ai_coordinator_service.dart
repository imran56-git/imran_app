import 'dart:async';
import 'gemini_service.dart';
import 'fallback_ai_service.dart';
import '../utils/ai_cooldown_manager.dart';

enum AppLanguage { en, bn, hi }

class AiCoordinatorService {
  static final AiCoordinatorService _instance = AiCoordinatorService._internal();
  factory AiCoordinatorService() => _instance;
  AiCoordinatorService._internal();

  final GeminiService _geminiService = GeminiService();
  final FallbackAiService _fallbackService = FallbackAiService();
  final AiCooldownManager _cooldownManager = AiCooldownManager();

  AppLanguage _detectLanguage(String text) {
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(text)) {
      return AppLanguage.bn;
    } else if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      return AppLanguage.hi;
    }
    return AppLanguage.en;
  }

  String _getFallbackNotice(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.bn:
        return '⚠️ স্যরি স্যার! FYBTT প্রধান সার্ভার সাময়িক ব্যস্ত থাকায় ব্যাকআপ এআই ইঞ্জিন চালু করা হয়েছে। অনুগ্রহ করে কয়েক সেকেন্ড অপেক্ষা করুন...\n\n';
      case AppLanguage.hi:
        return '⚠️ क्षमा करें सर! FYBTT मुख्य सर्वर व्यस्त होने के कारण बैकअप एआई इंजन सक्रिय किया गया है। कृपया कुछ सेकंड प्रतीक्षा करें...\n\n';
      case AppLanguage.en:
        return '⚠️ Sorry sir! Due to heavy traffic on the FYBTT primary server, our backup AI engine has been activated. Please wait a few seconds...\n\n';
    }
  }

  String _getBusyMessage(AppLanguage lang, String waitTime) {
    switch (lang) {
      case AppLanguage.bn:
        return 'সার্ভার সাময়িক ব্যস্ত। অনুগ্রহ করে $waitTime অপেক্ষা করুন।';
      case AppLanguage.hi:
        return 'सर्वर अभी व्यस्त है। कृपया $waitTime प्रतीक्षा करें।';
      case AppLanguage.en:
        return 'Server is temporarily busy. Please wait $waitTime.';
    }
  }

  String _getQuotaExceededMessage(AppLanguage lang, String waitTime) {
    switch (lang) {
      case AppLanguage.bn:
        return 'দৈনিক ফ্রি কোটা শেষ হয়ে গেছে। অনুগ্রহ করে $waitTime পর আবার চেষ্টা করুন।';
      case AppLanguage.hi:
        return 'दैनिक फ्री कोटा समाप्त हो गया है। कृपया $waitTime बाद पुनः प्रयास करें।';
      case AppLanguage.en:
        return 'Daily free quota exceeded. Please try again after $waitTime.';
    }
  }

  String _getHighTrafficMessage(AppLanguage lang, String waitTime) {
    switch (lang) {
      case AppLanguage.bn:
        return '✨ FYBTT Assistant বর্তমানে উচ্চ ট্রাফিকের মধ্যে রয়েছে। অনুগ্রহ করে $waitTime পর আবার চেষ্টা করুন।';
      case AppLanguage.hi:
        return '✨ FYBTT Assistant वर्तमान में उच्च ट्रैफ़िक पर है। कृपया $waitTime बाद पुनः प्रयास करें।';
      case AppLanguage.en:
        return '✨ FYBTT Assistant is handling high traffic right now. Please try again in $waitTime.';
    }
  }

  bool _isQuotaError(dynamic error) {
    final str = error.toString().toLowerCase();
    return str.contains('quota') ||
        str.contains('resourceexhausted') ||
        str.contains('daily limit') ||
        str.contains('exceeded your current quota');
  }

  Stream<String> sendMessageStream(String prompt, {String? systemPrompt}) async* {
    final lang = _detectLanguage(prompt);

    if (_cooldownManager.isInCooldown) {
      final waitTime = _cooldownManager.formattedRemainingTime;
      yield _getBusyMessage(lang, waitTime);
      return;
    }

    bool geminiSucceeded = false;
    try {
      final stream = _geminiService.generateContentStream(prompt, systemPrompt: systemPrompt);
      await for (final chunk in stream) {
        geminiSucceeded = true;
        yield chunk;
      }
      return;
    } catch (e) {
      if (geminiSucceeded) {
        return;
      }

      if (_isQuotaError(e)) {
        await _cooldownManager.setDailyQuotaCooldown();
      }

      yield _getFallbackNotice(lang);

      try {
        final fallbackStream = _fallbackService.generateContentStream(
          prompt,
          systemPrompt: systemPrompt,
        );
        await for (final chunk in fallbackStream) {
          yield chunk;
        }
      } catch (fallbackError) {
        if (_isQuotaError(fallbackError)) {
          await _cooldownManager.setDailyQuotaCooldown();
          yield _getQuotaExceededMessage(lang, _cooldownManager.formattedRemainingTime);
        } else {
          await _cooldownManager.setShortCooldown(seconds: 45);
          yield _getHighTrafficMessage(lang, _cooldownManager.formattedRemainingTime);
        }
      }
    }
  }

  Future<String> sendMessage(String prompt, {String? systemPrompt}) async {
    final lang = _detectLanguage(prompt);

    if (_cooldownManager.isInCooldown) {
      final waitTime = _cooldownManager.formattedRemainingTime;
      return _getBusyMessage(lang, waitTime);
    }

    try {
      return await _geminiService.generateContent(prompt, systemPrompt: systemPrompt);
    } catch (e) {
      if (_isQuotaError(e)) {
        await _cooldownManager.setDailyQuotaCooldown();
      }

      final notice = _getFallbackNotice(lang);

      try {
        final fallbackResponse = await _fallbackService.generateContent(
          prompt,
          systemPrompt: systemPrompt,
        );
        return '$notice$fallbackResponse';
      } catch (fallbackError) {
        if (_isQuotaError(fallbackError)) {
          await _cooldownManager.setDailyQuotaCooldown();
          return _getQuotaExceededMessage(lang, _cooldownManager.formattedRemainingTime);
        } else {
          await _cooldownManager.setShortCooldown(seconds: 45);
          return _getHighTrafficMessage(lang, _cooldownManager.formattedRemainingTime);
        }
      }
    }
  }
}
