import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/sonoritiz_icon_button.dart';

class PlayerPrimaryControls extends StatelessWidget {
  final bool isPlaying;
  final bool isShuffleModeEnabled;
  final LoopMode loopMode;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;

  const PlayerPrimaryControls({
    Key? key,
    required this.isPlaying,
    required this.isShuffleModeEnabled,
    required this.loopMode,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SonoritizIconButton(
            icon: Icons.shuffle_rounded,
            tooltip: "Aléatoire",
            color: isShuffleModeEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
            iconSize: AppDimensions.iconMd,
            onPressed: onShuffle,
          ),
          SonoritizIconButton(
            icon: Icons.skip_previous_rounded,
            tooltip: "Précédent",
            iconSize: AppDimensions.iconLg,
            onPressed: onPrevious,
          ),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: SonoritizIconButton(
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              tooltip: isPlaying ? "Pause" : "Lecture",
              color: colorScheme.onPrimary,
              iconSize: 40.0,
              size: 72.0,
              onPressed: onPlayPause,
            ),
          ),
          SonoritizIconButton(
            icon: Icons.skip_next_rounded,
            tooltip: "Suivant",
            iconSize: AppDimensions.iconLg,
            onPressed: onNext,
          ),
          SonoritizIconButton(
            icon: loopMode == LoopMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            tooltip: "Répéter",
            color: loopMode != LoopMode.off ? colorScheme.primary : colorScheme.onSurfaceVariant,
            iconSize: AppDimensions.iconMd,
            onPressed: onRepeat,
          ),
        ],
      ),
    );
  }
}
