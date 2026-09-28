import 'package:flutter/material.dart';

class ScreenPullController {
  static bool _isNavigating = false;

  /// বর্তমান নেভিগেশন লক স্ট্যাটাস চেক করতে
  static bool get isNavigating => _isNavigating;

  /// নিরাপদ নেভিগেশন এক্সিকিউট করার মেথড (ডাবল-ট্যাপ সেফটিসহ)
  static Future<void> executeSafeNavigation({
    required BuildContext context,
    required Future<void> Function() navigationAction,
    Duration lockDuration = const Duration(milliseconds: 750),
  }) async {
    if (_isNavigating) return;

    _isNavigating = true;

    try {
      if (context.mounted) {
        await navigationAction();
      }
    } catch (e) {
      debugPrint("ScreenPullController Exception: $e");
    } finally {
      Future.delayed(lockDuration, () {
        _isNavigating = false;
      });
    }
  }

  /// GlobalKey ব্যবহার করে যেকোনো উইজেটের গ্লোবাল সেন্টার কোঅর্ডিনেট নির্ণয়
  static Offset? getWidgetCenterBounds(GlobalKey key) {
    try {
      final RenderBox? renderBox =
          key.currentContext?.findRenderObject() as RenderBox?;
          
      if (renderBox != null && renderBox.hasSize) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        return Offset(
          position.dx + (size.width / 2),
          position.dy + (size.height / 2),
        );
      }
    } catch (e) {
      debugPrint("Error fetching widget bounds: $e");
    }
    return null;
  }
}
