import 'package:flutter/material.dart';

class AppDecorations {
  // Opacity
  static const double opacityHover = 0.08;
  static const double opacityFocus = 0.12;
  static const double opacityPressed = 0.12;
  static const double opacityDragged = 0.16;
  static const double opacityDisabled = 0.38;
  static const double opacityOverlay = 0.50;

  // Shadows (Elevations)
  static List<BoxShadow> shadowSm(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> shadowMd(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> shadowLg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.5 : 0.12),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static List<BoxShadow> playerGlow(Color dominantColor) {
    return [
      BoxShadow(
        color: dominantColor.withOpacity(0.4),
        blurRadius: 40,
        spreadRadius: 4,
        offset: const Offset(0, 15),
      ),
    ];
  }
}
