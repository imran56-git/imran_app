import 'package:flutter/material.dart';

class AnimationConstants {
  // Navigation Transition Timing
  static const Duration pullDuration = Duration(milliseconds: 320);
  static const Duration crossoverDuration = Duration(milliseconds: 60);
  static const Duration emergeDuration = Duration(milliseconds: 320);

  static Duration get totalTransitionDuration =>
      pullDuration + crossoverDuration + emergeDuration;

  // Menu Animation Timing
  static const Duration menuItemStaggerDelay = Duration(milliseconds: 70);
  static const Duration menuItemDuration = Duration(milliseconds: 250);

  // Motion Curves
  static const Curve pullCurve = Curves.easeInCubic;
  static const Curve emergeCurve = Curves.easeOutCubic;

  // Visual Warp / Perspective Constants
  static const double perspectiveStrength = 0.0025;
  static const double deformationStrength = 1.8;
  static const double maxCornerConvergence = 0.95;
}
