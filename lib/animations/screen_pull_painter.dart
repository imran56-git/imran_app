import 'dart:ui';
import 'package:flutter/material.dart';

class ScreenPullWarpWidget extends StatelessWidget {
  final Widget child;
  final double progress; // 0.0 (Full Screen) -> 1.0 (Pulled into point)
  final Offset pullPoint;
  final bool isDisappearing;

  const ScreenPullWarpWidget({
    super.key,
    required this.child,
    required this.progress,
    required this.pullPoint,
    this.isDisappearing = true,
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.001 && isDisappearing) return child;
    if (progress >= 0.999 && !isDisappearing) return child;

    final Size size = MediaQuery.of(context).size;

    // Relative pull point in normalized alignment coordinates (-1.0 to 1.0)
    final double alignX = (size.width > 0)
        ? ((pullPoint.dx / size.width) * 2 - 1.0).clamp(-1.0, 1.0)
        : 0.0;
    final double alignY = (size.height > 0)
        ? ((pullPoint.dy / size.height) * 2 - 1.0).clamp(-1.0, 1.0)
        : 0.0;

    final double effectiveProgress =
        isDisappearing ? progress : (1.0 - progress);

    // Perspective & non-uniform suction matrix calculation
    final double scale = (1.0 - effectiveProgress).clamp(0.001, 1.0);
    final double perspective = 0.002 * effectiveProgress;

    final double transX =
        (pullPoint.dx - (size.width / 2)) * effectiveProgress;
    final double transY =
        (pullPoint.dy - (size.height / 2)) * effectiveProgress;

    return Transform(
      alignment: Alignment(alignX, alignY),
      transform: Matrix4.identity()
        ..setEntry(3, 2, perspective)
        ..translate(transX, transY)
        ..scale(scale, scale, 1.0)
        ..rotateZ((isDisappearing ? 0.04 : -0.04) * effectiveProgress),
      child: Opacity(
        opacity: (1.0 - (effectiveProgress * 0.85)).clamp(0.0, 1.0),
        child: ClipRect(
          child: child,
        ),
      ),
    );
  }
}
