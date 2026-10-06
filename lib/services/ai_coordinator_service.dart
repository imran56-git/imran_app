import 'dart:async';
import 'package:flutter/foundation.dart';
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

  AppLanguage detectLanguage(String text) {
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(text)) {
      return AppLanguage.bn;
    } else if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      return AppLanguage.hi;
    }
    return AppLanguage.en;
  }

  String getFallbackNoticeText(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.bn:
        return 'FYBTT ব্যাকআপ এআই সক্রিয় হচ্ছে...';
      case AppLanguage.hi:
        return 'FYBTT बैकअप एआई सक्रिय हो रहा है...';
      case AppLanguage.en:
        return 'Activating FYBTT backup AI...';
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

  String _getGeneralErrorMessage(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.bn:
        return '⚠️ সার্ভারের সাথে সংযোগ বিচ্ছিন্ন হয়েছে। অনুগ্রহ করে ইন্টারনেট চেক করে আবার প্রশ্ন করুন।';
      case AppLanguage.hi:
        return '⚠️ सर्वर कनेक्शन में समस्या आई। कृपया पुनः प्रयास करें।';
      case AppLanguage.en:
        return '⚠️ Unable to connect to servers. Please try again in a moment.';
    }
  }

  bool _isQuotaError(dynamic error) {
    final str = error.toString().toLowerCase();
    return str.contains('429') ||
        str.contains('quota') ||
        str.contains('resourceexhausted') ||
        str.contains('daily limit') ||
        str.contains('exceeded your current quota');
  }

  Stream<String> sendMessageStream(
    String prompt, {
    String? systemPrompt,
    void Function(bool isFallbackActive)? onFallbackStatus,
  }) async* {
    final lang = detectLanguage(prompt);

    if (_cooldownManager.isInCooldown) {
      final waitTime = _cooldownManager.formattedRemainingTime;
      yield _getBusyMessage(lang, waitTime);
      return;
    }

    bool geminiEmittedAny = false;
    try {
      final stream = _geminiService.generateContentStream(
        prompt,
        systemPrompt: systemPrompt,
      );
      await for (final chunk in stream) {
        geminiEmittedAny = true;
        yield chunk;
      }
      return;
    } catch (geminiError) {
      debugPrint("Primary Gemini failed: $geminiError");
      if (geminiEmittedAny) return;

      onFallbackStatus?.call(true);

      try {
        final fallbackStream = _fallbackService.generateContentStream(
          prompt,
          systemPrompt: systemPrompt,
        );
        await for (final chunk in fallbackStream) {
          yield chunk;
        }
      } catch (fallbackError) {
        debugPrint("Fallback Groq also failed: $fallbackError");
        if (_isQuotaError(fallbackError) || _isQuotaError(geminiError)) {
          await _cooldownManager.setShortCooldown(seconds: 20);
          yield _getQuotaExceededMessage(lang, _cooldownManager.formattedRemainingTime);
        } else {
          yield _getGeneralErrorMessage(lang);
        }
      } finally {
        onFallbackStatus?.call(false);
      }
    }
  }

  Future<String> sendMessage(String prompt, {String? systemPrompt}) async {
    final lang = detectLanguage(prompt);

    if (_cooldownManager.isInCooldown) {
      final waitTime = _cooldownManager.formattedRemainingTime;
      return _getBusyMessage(lang, waitTime);
    }

    try {
      return await _geminiService.generateContentStream(prompt, systemPrompt: systemPrompt).join();
    } catch (e) {
      try {
        return await _fallbackService.generateContent(
          prompt,
          systemPrompt: systemPrompt,
        );
      } catch (fallbackError) {
        if (_isQuotaError(fallbackError) || _isQuotaError(e)) {
          await _cooldownManager.setShortCooldown(seconds: 20);
          return _getQuotaExceededMessage(lang, _cooldownManager.formattedRemainingTime);
        } else {
          return _getGeneralErrorMessage(lang);
        }
      }
    }
  }
}
