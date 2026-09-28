import 'package:flutter/material.dart';
import 'animation_constants.dart';
import 'screen_pull_warp_widget.dart'; 

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
    final Animation<double> pullAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        0.0,
        0.5,
        curve: AnimationConstants.pullCurve,
      ),
    );

    final Animation<double> emergeAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        0.5,
        1.0,
        curve: AnimationConstants.emergeCurve,
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double val = animation.value;

        // Phase 1: Pull Outgoing Screen into Vanishing Point (0.0 -> 0.5)
        if (val <= 0.5) {
          return ScreenPullWarpWidget(
            progress: pullAnimation.value,
            pullPoint: pullPoint,
            isDisappearing: true,
            child: outgoingChild,
          );
        }
        // Phase 2: Emerge Incoming Screen from Vanishing Point (0.5 -> 1.0)
        else {
          return ScreenPullWarpWidget(
            progress: emergeAnimation.value, 
            pullPoint: pullPoint,
            isDisappearing: false,
            child: incomingChild,
          );
        }
      },
    );
  }
}
