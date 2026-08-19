import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/player/data/models/track_model.dart';
import '../../../../features/player/presentation/cubit/player_cubit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

class ShortMiniPlayerWidget extends StatelessWidget {
  final TrackModel track;
  final bool isPlaying;
  final double progress; // 0.0 to 1.0 (for the 20s short)
  final VoidCallback onPlayPause;
  final VoidCallback onOpenFullPlayer;
  final Color progressColor;

  const ShortMiniPlayerWidget({
    Key? key,
    required this.track,
    required this.isPlaying,
    required this.progress,
    required this.onPlayPause,
    required this.onOpenFullPlayer,
    required this.progressColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Pause short audio
        onOpenFullPlayer();
        // Lancer le lecteur global avec ce son
        context.read<PlayerCubit>().playTrack(track);
        context.push('/fullscreen');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: track.coverUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[900]),
                    errorWidget: (context, url, error) => const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.artistName,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Play/Pause for the Short
                IconButton(
                  icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32),
                  onPressed: onPlayPause,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress Bar (20s)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
