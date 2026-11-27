import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../core/widgets/sonoritiz_track_tile.dart';
import '../cubit/player_cubit.dart';
import '../cubit/player_state.dart';

class QueueBottomSheet extends StatelessWidget {
  const QueueBottomSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerCubit, PlayerState>(
      buildWhen: (prev, cur) =>
          prev.queue != cur.queue ||
          prev.currentIndex != cur.currentIndex ||
          prev.isPlaying != cur.isPlaying ||
          prev.playbackSource != cur.playbackSource ||
          prev.userQueuedTrackIds != cur.userQueuedTrackIds,
      builder: (context, state) {
        final currentTrack = state.currentTrack;
        final String sourceLabel = state.playbackSource.trim().isNotEmpty
            ? state.playbackSource.trim()
            : 'Votre sélection';

        // Comptage des titres « À lire ensuite » situés après le morceau actif
        int upNextCount = 0;
        int firstContinuationIndex = -1;
        for (int i = state.currentIndex + 1; i < state.queue.length; i++) {
          final isUserQueued =
              state.userQueuedTrackIds.contains(state.queue[i].id);
          if (isUserQueued) {
            upNextCount++;
          } else if (firstContinuationIndex == -1) {
            firstContinuationIndex = i;
          }
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.80,
          decoration: BoxDecoration(
            color: const Color(0xFF101015),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.11),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // En-tête de la file d'attente
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.38),
                        ),
                      ),
                      child: const Icon(
                        Icons.queue_music_rounded,
                        color: AppColors.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "File d'attente",
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${state.queue.length} titres • Glisse pour réordonner ou balaye pour retirer",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11.8,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (upNextCount > 0)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.read<PlayerCubit>().clearUserUpNext();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: const Text(
                            "Vider suivants",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Carte « En cours de lecture » épinglée
              if (currentTrack != null) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.20),
                          const Color(0xFF171720),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      children: [
                        SonoritizArtwork(
                          imageUrl: currentTrack.coverUrl,
                          width: 48,
                          height: 48,
                          borderRadius: 11,
                          cacheMaxDimension: 150,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "EN COURS",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      sourceLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.65),
                                        fontSize: 11.2,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentTrack.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                currentTrack.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.graphic_eq_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),

              // Liste réordonnable avec sections « À lire ensuite » et « Suite de : ... »
              Expanded(
                child: state.queue.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_off_rounded,
                              size: 58,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              "La file d'attente est vide.",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 15.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ReorderableListView.builder(
                        padding:
                            const EdgeInsets.only(top: 6.0, bottom: 40.0),
                        physics: const BouncingScrollPhysics(),
                        itemCount: state.queue.length,
                        onReorder: (oldIndex, newIndex) {
                          HapticFeedback.selectionClick();
                          context
                              .read<PlayerCubit>()
                              .reorderQueue(oldIndex, newIndex);
                        },
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            color: const Color(0xFF1A1A24),
                            borderRadius: BorderRadius.circular(14),
                            elevation: 14,
                            child: child,
                          );
                        },
                        itemBuilder: (context, index) {
                          final track = state.queue[index];
                          final isCurrent = index == state.currentIndex;
                          final isUserUpNext = index > state.currentIndex &&
                              state.userQueuedTrackIds.contains(track.id);
                          final bool showUpNextHeader =
                              index == state.currentIndex + 1 && isUserUpNext;
                          final bool showContinuationHeader =
                              index == firstContinuationIndex ||
                              (index == state.currentIndex + 1 &&
                                  !isUserUpNext);

                          return Column(
                            key: ValueKey('q_${track.id}_$index'),
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showUpNextHeader)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    12,
                                    18,
                                    4,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.playlist_play_rounded,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        "À LIRE ENSUITE",
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.18),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          "$upNextCount",
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (showContinuationHeader)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    14,
                                    18,
                                    4,
                                  ),
                                  child: Text(
                                    "SUITE DE : ${sourceLabel.toUpperCase()}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.52),
                                      fontSize: 11.2,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                ),
                              Dismissible(
                                key: ValueKey('dismiss_q_${track.id}_$index'),
                                direction: isCurrent
                                    ? DismissDirection.none
                                    : DismissDirection.endToStart,
                                onDismissed: (_) {
                                  HapticFeedback.lightImpact();
                                  context
                                      .read<PlayerCubit>()
                                      .removeFromQueueAt(index);
                                },
                                background: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 4,
                                  ),
                                  padding: const EdgeInsets.only(right: 20),
                                  alignment: Alignment.centerRight,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent
                                        .withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Retirer",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(
                                        Icons.remove_circle_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 19,
                                      ),
                                    ],
                                  ),
                                ),
                                child: SonoritizTrackTile(
                                  track: track,
                                  queue: state.queue,
                                  enableSwipeActions: false,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isUserUpNext)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(right: 8),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.16),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.45),
                                            ),
                                          ),
                                          child: const Text(
                                            "SUIVANT",
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      if (isCurrent && state.isPlaying)
                                        const Icon(
                                          Icons.equalizer_rounded,
                                          color: AppColors.primary,
                                        )
                                            .animate(
                                              onPlay: (controller) =>
                                                  controller.repeat(),
                                            )
                                            .shimmer(duration: 1000.ms)
                                      else
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: Padding(
                                            padding: const EdgeInsets.all(6.0),
                                            child: Icon(
                                              Icons.drag_handle_rounded,
                                              color: Colors.white
                                                  .withValues(alpha: 0.36),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  onTap: () {
                                    context
                                        .read<PlayerCubit>()
                                        .skipToQueueItem(index);
                                  },
                                ),
                              ),
                              Divider(
                                color: Colors.white.withValues(alpha: 0.08),
                                height: 1,
                                thickness: 0.7,
                                indent: 16,
                                endIndent: 16,
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
