import 'dart:ui';
import 'package:flutter/material.dart';

class ScreenPullWarpWidget extends StatelessWidget {
  final Widget child;
  /// 0.0 (Full Screen) -> 1.0 (Pulled into target point)
  final double progress;
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
    // ১. প্রারম্ভিক এবং প্রান্তিক অবস্থা সরাসরি হ্যান্ডেল করা
    if (progress <= 0.001 && isDisappearing) return child;
    if (progress >= 0.999 && !isDisappearing) return child;
    if (progress >= 0.999 && isDisappearing) return const SizedBox.shrink();

    final Size size = MediaQuery.of(context).size;
    if (size.width == 0 || size.height == 0) return child;

    // ২. Pull Point-কে Normalized Alignment (-1.0 to 1.0) এ রূপান্তর
    final double alignX = ((pullPoint.dx / size.width) * 2 - 1.0).clamp(-1.0, 1.0);
    final double alignY = ((pullPoint.dy / size.height) * 2 - 1.0).clamp(-1.0, 1.0);

    final double effectiveProgress = isDisappearing ? progress : (1.0 - progress);

    // ৩. ৩ডি স্কেলিং ও পার্সপেক্টিভ হিসেব
    final double scale = (1.0 - effectiveProgress).clamp(0.001, 1.0);
    final double perspective = 0.002 * effectiveProgress;
    final double rotationZ = (isDisappearing ? 0.05 : -0.05) * effectiveProgress;

    return Transform(
      alignment: Alignment(alignX, alignY),
      transform: Matrix4.identity()
        ..setEntry(3, 2, perspective)
        ..scale(scale, scale, 1.0)
        ..rotateZ(rotationZ),
      child: Opacity(
        opacity: (1.0 - (effectiveProgress * 0.85)).clamp(0.0, 1.0),
        child: ClipRect(
          child: child,
        ),
      ),
    );
  }
}
