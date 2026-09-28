import 'package:flutter/material.dart';
import 'animation_constants.dart';
import 'screen_pull_painter.dart';

class ScreenPullTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget outgoingChild;
  final Widget incomingChild;
  final Offset pullPoint;

  const ScreenPullTransition({
    super.key,
    required this.animation,
    required this.outgoingChild,
    required this.incomingChild,
    required this.pullPoint,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double val = animation.value;

        // Phase 1: Pull Outgoing Screen into Vanishing Point (0.0 to 0.5)
        if (val <= 0.5) {
          final double pullProgress = (val / 0.5).clamp(0.0, 1.0);
          final double curvedProgress =
              AnimationConstants.pullCurve.transform(pullProgress);

          return ScreenPullWarpWidget(
            progress: curvedProgress,
            pullPoint: pullPoint,
            isDisappearing: true,
            child: outgoingChild,
          );
        }
        // Phase 2: Emerge Incoming Screen from Vanishing Point (0.5 to 1.0)
        else {
          final double emergeProgress = ((val - 0.5) / 0.5).clamp(0.0, 1.0);
          final double curvedProgress =
              AnimationConstants.emergeCurve.transform(emergeProgress);

          return ScreenPullWarpWidget(
            progress: 1.0 - curvedProgress,
            pullPoint: pullPoint,
            isDisappearing: false,
            child: incomingChild,
          );
        }
      },
    );
  }
}
