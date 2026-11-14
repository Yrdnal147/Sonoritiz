import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/widgets/sonoritiz_icon_button.dart';

class PlayerPrimaryControls extends StatelessWidget {
  final bool isPlaying;
  final bool isBuffering;
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
    this.isBuffering = false,
    required this.isShuffleModeEnabled,
    required this.loopMode,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onShuffle,
    required this.onRepeat,
  }) : super(key: key);

  Widget _buildModeButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SonoritizIconButton(
          icon: icon,
          tooltip: tooltip,
          color: isActive ? activeColor : Colors.white70,
          iconSize: AppDimensions.iconMd,
          onPressed: onPressed,
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: isActive ? 5 : 0,
          height: isActive ? 5 : 0,
          decoration: BoxDecoration(
            color: activeColor,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [BoxShadow(color: activeColor.withOpacity(0.8), blurRadius: 6)]
                : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildModeButton(
            icon: Icons.shuffle_rounded,
            tooltip: "Aléatoire",
            isActive: isShuffleModeEnabled,
            activeColor: colorScheme.tertiary,
            onPressed: onShuffle,
          ),
          SonoritizIconButton(
            icon: Icons.skip_previous_rounded,
            tooltip: "Précédent",
            color: Colors.white,
            iconSize: AppDimensions.iconLg,
            onPressed: onPrevious,
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.28),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: isBuffering
                ? const SizedBox(
                    width: 72.0,
                    height: 72.0,
                    child: Padding(
                      padding: EdgeInsets.all(22.0),
                      child: RepaintBoundary(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  )
                : SonoritizIconButton(
                    icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    tooltip: isPlaying ? "Pause" : "Lecture",
                    color: Colors.black,
                    iconSize: 40.0,
                    size: 72.0,
                    onPressed: onPlayPause,
                  ),
          ),
          SonoritizIconButton(
            icon: Icons.skip_next_rounded,
            tooltip: "Suivant",
            color: Colors.white,
            iconSize: AppDimensions.iconLg,
            onPressed: onNext,
          ),
          _buildModeButton(
            icon: loopMode == LoopMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            tooltip: "Répéter",
            isActive: loopMode != LoopMode.off,
            activeColor: colorScheme.tertiary,
            onPressed: onRepeat,
          ),
        ],
      ),
    );
  }
}
