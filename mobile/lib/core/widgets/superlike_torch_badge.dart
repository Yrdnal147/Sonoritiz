import 'package:flutter/material.dart';
import 'superlike_vibration_heart.dart';

enum TorchBadgeSize { small, medium, large }

/// Badge Superlike officiel Sonoritiz (Cœur vibrant d'ondes acoustiques).
/// Maintient la rétrocompatibilité des noms tout en affichant le cœur de vibration.
class SuperlikeTorchBadge extends StatelessWidget {
  final TorchBadgeSize size;
  final bool showBackground;
  final bool animateGlow;

  const SuperlikeTorchBadge({
    Key? key,
    this.size = TorchBadgeSize.small,
    this.showBackground = true,
    this.animateGlow = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    SuperlikeBadgeSize targetSize;
    switch (size) {
      case TorchBadgeSize.small:
        targetSize = SuperlikeBadgeSize.small;
        break;
      case TorchBadgeSize.medium:
        targetSize = SuperlikeBadgeSize.medium;
        break;
      case TorchBadgeSize.large:
        targetSize = SuperlikeBadgeSize.large;
        break;
    }

    return SuperlikeVibrationHeart(
      size: targetSize,
      showBackground: showBackground,
      animatePulse: animateGlow,
    );
  }
}
