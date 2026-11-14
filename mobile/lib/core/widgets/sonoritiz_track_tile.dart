import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../features/player/data/models/track_model.dart';
import '../../../features/player/presentation/cubit/player_cubit.dart';
import '../../../features/player/presentation/cubit/player_state.dart';
import '../theme/app_colors.dart';
import 'sonoritiz_artwork.dart';
import 'track_context_menu.dart';
import 'playing_indicator_overlay.dart';
import 'superlike_torch_badge.dart';
import '../../../features/player/presentation/cubit/superlike_cubit.dart';
import '../../../features/player/presentation/cubit/superlike_state.dart';

class SonoritizTrackTile extends StatelessWidget {
  final TrackModel track;
  final List<TrackModel> queue;
  final int? index;
  final bool showCover;
  final String? coverOverride;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectionChanged;
  final int? playlistId;
  final String? playbackSource;

  const SonoritizTrackTile({
    Key? key,
    required this.track,
    required this.queue,
    this.index,
    this.showCover = true,
    this.coverOverride,
    this.onTap,
    this.trailing,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionChanged,
    this.playlistId,
    this.playbackSource,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveCover =
        (coverOverride != null && coverOverride!.isNotEmpty)
            ? coverOverride!
            : track.coverUrl;

    return BlocSelector<PlayerCubit, PlayerState, bool>(
      selector: (state) => state.currentTrack?.id == track.id,
      builder: (context, isCurrentTrack) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index != null)
                SizedBox(
                  width: 30,
                  child: Center(
                    child: Text(
                      "${index! + 1}",
                      style: TextStyle(
                        color: isCurrentTrack
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (index != null && showCover) const SizedBox(width: 8),
              if (showCover)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PlayingIndicatorOverlay(
                          trackId: track.id,
                          child: SonoritizArtwork(
                            imageUrl: effectiveCover,
                            width: 48,
                            height: 48,
                            borderRadius: 0,
                            cacheMaxDimension: 160,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: BlocBuilder<SuperlikeCubit, SuperlikeState>(
                            builder: (context, state) {
                              if (!state.isSuperliked(track.id)) {
                                return const SizedBox.shrink();
                              }
                              return const SuperlikeTorchBadge(
                                size: TorchBadgeSize.small,
                                showBackground: true,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrentTrack ? AppColors.primary : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16.5,
            ),
          ),
          subtitle: Text(
            track.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrentTrack
                  ? AppColors.primary.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.72),
              fontSize: 14.5,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null) trailing!,
              if (trailing == null && !isSelectionMode)
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                  onPressed: () => TrackContextMenu.show(
                    context,
                    track,
                    playlistId: playlistId,
                  ),
                ),
              if (isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: onSelectionChanged,
                  activeColor: AppColors.primary,
                ),
            ],
          ),
          onTap: isSelectionMode
              ? () => onSelectionChanged?.call(!isSelected)
              : (onTap ??
                  () => context.read<PlayerCubit>().playTrack(
                        track,
                        queue: queue,
                        source: playbackSource,
                      )),
          onLongPress: isSelectionMode
              ? null
              : (onSelectionChanged != null
                  ? () => onSelectionChanged!.call(true)
                  : () => TrackContextMenu.show(
                        context,
                        track,
                        playlistId: playlistId,
                      )),
        );
      },
    );
  }
}
