import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiCooldownManager extends ChangeNotifier {
  static final AiCooldownManager _instance = AiCooldownManager._internal();
  factory AiCooldownManager() => _instance;
  AiCooldownManager._internal();

  static const String _prefCooldownEndTime = 'ai_cooldown_end_time';
  static const String _prefIsDailyQuota = 'ai_is_daily_quota';

  DateTime? _cooldownEndTime;
  bool _isDailyQuota = false;
  Timer? _tickerTimer;

  bool get isInCooldown {
    if (_cooldownEndTime == null) return false;
    return DateTime.now().isBefore(_cooldownEndTime!);
  }

  bool get isDailyQuota => _isDailyQuota;

  Duration get remainingDuration {
    if (!isInCooldown || _cooldownEndTime == null) return Duration.zero;
    final rem = _cooldownEndTime!.difference(DateTime.now());
    return rem.isNegative ? Duration.zero : rem;
  }

  int get remainingSeconds => remainingDuration.inSeconds;

  String get formattedRemainingTime {
    final d = remainingDuration;
    if (d.inSeconds <= 0) return '00:00';

    if (_isDailyQuota || d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    } else {
      final minutes = d.inMinutes.toString().padLeft(2, '0');
      final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final storedEpoch = prefs.getInt(_prefCooldownEndTime);
    _isDailyQuota = prefs.getBool(_prefIsDailyQuota) ?? false;

    if (storedEpoch != null) {
      final endTime = DateTime.fromMillisecondsSinceEpoch(storedEpoch);
      if (DateTime.now().isBefore(endTime)) {
        _cooldownEndTime = endTime;
        _startTicker();
      } else {
        await clearCooldown();
      }
    }
  }

  Future<void> setShortCooldown({int seconds = 30}) async {
    await _applyCooldown(Duration(seconds: seconds), isDaily: false);
  }

  Future<void> setDailyQuotaCooldown() async {
    await _applyCooldown(const Duration(hours: 24), isDaily: true);
  }

  Future<void> _applyCooldown(Duration duration, {required bool isDaily}) async {
    _cooldownEndTime = DateTime.now().add(duration);
    _isDailyQuota = isDaily;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefCooldownEndTime, _cooldownEndTime!.millisecondsSinceEpoch);
    await prefs.setBool(_prefIsDailyQuota, isDaily);

    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isInCooldown) {
        clearCooldown();
      } else {
        notifyListeners();
      }
    });
  }

  Future<void> clearCooldown() async {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _cooldownEndTime = null;
    _isDailyQuota = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefCooldownEndTime);
    await prefs.remove(_prefIsDailyQuota);

    notifyListeners();
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }
}
