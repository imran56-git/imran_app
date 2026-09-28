import 'dart:ui';
import 'package:flutter/material.dart';

class ScreenPullWarpWidget extends StatelessWidget {
  final Widget child;
  final double progress; // 0.0 (Full Screen) -> 1.0 (Pulled into point)
  final Offset pullPoint;
  final bool isDisappearing;
  final bool enableBlur;
  final Color warpOverlayColor;

  const ScreenPullWarpWidget({
    super.key,
    required this.child,
    required this.progress,
    required this.pullPoint,
    this.isDisappearing = true,
    this.enableBlur = true,
    this.warpOverlayColor = const Color(0xFF1E4C7A),
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.001 && isDisappearing) return child;
    if (progress >= 0.999 && !isDisappearing) return child;
    if (progress >= 0.999 && isDisappearing) return const SizedBox.shrink();

    final Size size = MediaQuery.of(context).size;
    if (size.width == 0 || size.height == 0) return child;

    final double alignX = ((pullPoint.dx / size.width) * 2 - 1.0).clamp(-1.0, 1.0);
    final double alignY = ((pullPoint.dy / size.height) * 2 - 1.0).clamp(-1.0, 1.0);

    final double effectiveProgress = isDisappearing ? progress : (1.0 - progress);

    final double perspective = 0.0025 * effectiveProgress;
    final double baseScale = (1.0 - effectiveProgress).clamp(0.001, 1.0);

    final double scaleX = baseScale * (1.0 - (effectiveProgress * 0.12 * alignX.abs()));
    final double scaleY = baseScale * (1.0 - (effectiveProgress * 0.12 * alignY.abs()));

    final double rotateX = -alignY * 0.30 * effectiveProgress;
    final double rotateY = alignX * 0.30 * effectiveProgress;
    final double rotateZ = (isDisappearing ? 0.08 : -0.08) * effectiveProgress;

    final double blurSigma = enableBlur
        ? ((0.5 - (effectiveProgress - 0.5).abs()) * 2.0 * 3.5).clamp(0.0, 3.5)
        : 0.0;

    Widget bodyContent = Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(alignX, alignY),
                  radius: (1.5 - effectiveProgress).clamp(0.3, 1.5),
                  colors: [
                    Colors.transparent,
                    warpOverlayColor.withOpacity((effectiveProgress * 0.35).clamp(0.0, 0.35)),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (blurSigma > 0.2) {
      bodyContent = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: bodyContent,
      );
    }

    return RepaintBoundary(
      child: Transform(
        alignment: Alignment(alignX, alignY),
        transform: Matrix4.identity()
          ..setEntry(3, 2, perspective)
          ..rotateX(rotateX)
          ..rotateY(rotateY)
          ..rotateZ(rotateZ)
          ..scale(scaleX, scaleY, 1.0),
        child: Opacity(
          opacity: (1.0 - (effectiveProgress * 0.9)).clamp(0.0, 1.0),
          child: ClipRect(
            child: bodyContent,
          ),
        ),
      ),
    );
  }
}
