import 'package:flutter/material.dart';
import 'package:sonoritiz/core/widgets/wavy_progress_bar.dart';
import '../../cubit/player_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PlayerProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Widget? trailing;
  final bool? isPlaying;
  final bool isSuperliked;

  const PlayerProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.trailing,
    this.isPlaying,
    this.isSuperliked = false,
  });

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bool effectivePlaying = isPlaying ??
        context.select<PlayerCubit, bool>((cubit) => cubit.state.isPlaying);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: WavyProgressBar(
                    position: position,
                    duration: duration,
                    onSeek: onSeek,
                    isPlaying: effectivePlaying,
                    isSuperliked: isSuperliked,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 10.0,
              right: trailing != null ? 54.0 : 10.0,
              top: 0.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
