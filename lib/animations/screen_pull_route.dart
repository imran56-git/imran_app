import 'package:flutter/material.dart';
import 'animation_constants.dart';
import 'screen_pull_transition.dart';

class ScreenPullRoute<T> extends PageRouteBuilder<T> {
  final Widget destinationScreen;
  final Widget currentScreen;
  final Offset pullPoint;

  ScreenPullRoute({
    required this.destinationScreen,
    required this.currentScreen,
    required this.pullPoint,
    super.settings,
  }) : super(
          transitionDuration: AnimationConstants.totalTransitionDuration,
          reverseTransitionDuration: AnimationConstants.totalTransitionDuration,
          opaque: false,
          barrierDismissible: false,
          maintainState: true,
          pageBuilder: (context, animation, secondaryAnimation) => destinationScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return RepaintBoundary(
              child: ScreenPullTransition(
                animation: animation,
                outgoingChild: RepaintBoundary(child: currentScreen),
                incomingChild: child,
                pullPoint: pullPoint,
              ),
            );
          },
        );
}
