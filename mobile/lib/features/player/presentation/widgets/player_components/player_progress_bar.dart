import 'package:flutter/material.dart';
import '../../../../core/theme/app_dimensions.dart';

class PlayerProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const PlayerProgressBar({
    Key? key,
    required this.position,
    required this.duration,
    required this.onSeek,
  }) : super(key: key);

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingXl),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colorScheme.primary,
              inactiveTrackColor: colorScheme.surfaceContainerHighest,
              thumbColor: colorScheme.onSurface,
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: duration.inMilliseconds > 0
                  ? position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble())
                  : 0.0,
              max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0,
              onChanged: (val) {
                onSeek(Duration(milliseconds: val.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: textTheme.labelMedium,
                ),
                Text(
                  _formatDuration(duration),
                  style: textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
