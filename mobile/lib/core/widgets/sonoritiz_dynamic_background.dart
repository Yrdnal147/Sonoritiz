import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Fond sombre de l'application (noir épuré par défaut, lueur solaire optionnelle pour Connect).
class SonoritizDynamicBackground extends StatelessWidget {
  final Widget child;
  final bool enableDynamicArtwork;
  final bool keepWhenPaused;
  final bool enableSolarGlow;

  const SonoritizDynamicBackground({
    super.key,
    required this.child,
    this.enableDynamicArtwork = true,
    this.keepWhenPaused = false,
    this.enableSolarGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0E),
        gradient: enableSolarGlow
            ? RadialGradient(
                center: const Alignment(0.75, -0.92),
                radius: 1.25,
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  const Color(0xFF0C0C0E),
                ],
                stops: const [0.0, 0.85],
              )
            : null,
      ),
      child: child,
    );
  }
}
