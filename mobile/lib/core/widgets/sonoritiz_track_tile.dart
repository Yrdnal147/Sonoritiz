import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../features/library/presentation/cubit/library_cubit.dart';
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
  final bool enableSwipeActions;

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
    this.enableSwipeActions = true,
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
        final Widget tileContent = AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: isCurrentTrack
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isCurrentTrack
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 1,
                  )
                : null,
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (index != null)
                  SizedBox(
                    width: 30,
                    child: Center(
                      child: isCurrentTrack
                          ? const Icon(
                              Icons.graphic_eq_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : Text(
                              "${index! + 1}",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
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
                color: Colors.white,
                fontWeight: isCurrentTrack ? FontWeight.w800 : FontWeight.w700,
                fontSize: 16.5,
              ),
            ),
            subtitle: Text(
              track.artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrentTrack
                    ? Colors.white.withValues(alpha: 0.86)
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
                ? () => onSelectionChanged?.call(!isSelected)
                : () => TrackContextMenu.show(
                      context,
                      track,
                      playlistId: playlistId,
                    ),
          ),
        );

        if (isSelectionMode || !enableSwipeActions) {
          return tileContent;
        }

        // Gestes rapides « Swipe-to-Queue (Lire ensuite) » (droite) & « Swipe-to-Like » (gauche)
        return Dismissible(
          key: ValueKey('swipe_tile_${track.id}_${index ?? 0}'),
          direction: DismissDirection.horizontal,
          dismissThresholds: const {
            DismissDirection.startToEnd: 0.26,
            DismissDirection.endToStart: 0.26,
          },
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              HapticFeedback.mediumImpact();
              context.read<PlayerCubit>().playTrackNext(track);
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF181820),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  content: Row(
                    children: [
                      const Icon(
                        Icons.playlist_play_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '« ${track.title} » sera lu juste après',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (direction == DismissDirection.endToStart) {
              HapticFeedback.lightImpact();
              try {
                final libCubit = context.read<LibraryCubit>();
                final alreadyFav = libCubit.isFavorite(
                  track.id,
                  title: track.title,
                  artist: track.artistName,
                );
                if (alreadyFav) {
                  libCubit.removeFavorite(track.id);
                } else {
                  libCubit.addFavorite(track);
                }
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF181820),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    content: Row(
                      children: [
                        Icon(
                          alreadyFav
                              ? Icons.favorite_border_rounded
                              : Icons.favorite_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            alreadyFav
                                ? 'Retiré des favoris : « ${track.title} »'
                                : 'Ajouté aux favoris : « ${track.title} »',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } catch (_) {}
            }
            return false; // Retour élastique sans supprimer la ligne
          },
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.34),
                  AppColors.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.48),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.playlist_play_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  "Lire ensuite",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.pinkAccent.withValues(alpha: 0.08),
                  Colors.pinkAccent.withValues(alpha: 0.30),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.pinkAccent.withValues(alpha: 0.45),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Favoris",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.favorite_rounded,
                  color: Colors.pinkAccent,
                  size: 20,
                ),
              ],
            ),
          ),
          child: tileContent,
        );
      },
    );
  }
}
