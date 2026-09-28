import 'package:flutter/material.dart';

class ScreenPullController {
  static bool _isNavigating = false;

  static bool get isNavigating => _isNavigating;

  static Future<void> executeSafeNavigation({
    required BuildContext context,
    required Future<void> Function() navigationAction,
  }) async {
    if (_isNavigating) return;

    _isNavigating = true;

    try {
      await navigationAction();
    } catch (e) {
      debugPrint("ScreenPullController Exception: $e");
    } finally {
      Future.delayed(const Duration(milliseconds: 750), () {
        _isNavigating = false;
      });
    }
  }

  static Offset getWidgetCenterBounds(GlobalKey key) {
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
    } catch (_) {}
    return const Offset(200, 200);
  }
}
