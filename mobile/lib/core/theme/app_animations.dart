import 'package:flutter/material.dart';

class AppAnimations {
  // Durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);

  // Curves
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve decelerate = Curves.easeOutCubic; // Entrée d'éléments (BottomSheet)
  static const Curve accelerate = Curves.easeInCubic; // Sortie d'éléments
  static const Curve bounce = Curves.elasticOut; // Feedbacks (Like, Add to playlist)
}
