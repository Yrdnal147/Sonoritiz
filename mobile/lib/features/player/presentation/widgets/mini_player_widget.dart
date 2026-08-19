import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../core/widgets/sonoritiz_icon_button.dart';
import '../../../../core/widgets/artist_name_display.dart';
import '../cubit/player_cubit.dart';
import '../cubit/player_state.dart';
import '../screens/fullscreen_player_screen.dart';
import '../../data/models/track_model.dart';

class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlayerCubit, PlayerState, TrackModel?>(
      selector: (state) => state.currentTrack,
      builder: (context, track) {
        if (track == null) return const SizedBox.shrink();

        final colorScheme = Theme.of(context).colorScheme;

        return GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => BlocProvider.value(
                value: context.read<PlayerCubit>(),
                child: const FullscreenPlayerScreen(),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd, 
              vertical: AppDimensions.spacingXs
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: AppDimensions.miniPlayerHeight,
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    border: Border.all(color: colorScheme.outline.withOpacity(0.3), width: 1),
                  ),
                  child: Stack(
                    children: [
                      // Progress Bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          color: colorScheme.outline.withOpacity(0.2),
                          alignment: Alignment.centerLeft,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return BlocSelector<PlayerCubit, PlayerState, double>(
                                selector: (state) {
                                  if (state.duration.inMilliseconds > 0) {
                                    return (state.position.inMilliseconds / state.duration.inMilliseconds).clamp(0.0, 1.0);
                                  }
                                  return 0.0;
                                },
                                builder: (context, progress) {
                                  return Container(
                                    width: constraints.maxWidth * progress,
                                    color: colorScheme.primary,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingSm),
                        child: Row(
                          children: [
                            // Cover
                            Hero(
                              tag: 'cover_${track.id}',
                              child: SonoritizArtwork(
                                imageUrl: track.coverUrl,
                                width: 48,
                                height: 48,
                                borderRadius: AppDimensions.radiusMd,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacingMd),
                            
                            // Title & Artist
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  ArtistNameDisplay(
                                    artistName: track.artistName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            
                            // Controls
                            BlocSelector<PlayerCubit, PlayerState, bool>(
                              selector: (state) => state.isPlaying,
                              builder: (context, isPlaying) {
                                return SonoritizIconButton(
                                  icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  tooltip: isPlaying ? "Pause" : "Lecture",
                                  color: colorScheme.primary,
                                  backgroundColor: colorScheme.primaryContainer.withOpacity(0.5),
                                  onPressed: () => context.read<PlayerCubit>().togglePlayPause(),
                                ).animate(target: isPlaying ? 1 : 0).scaleXY(end: 1.05, duration: AppAnimations.fast);
                              },
                            ),
                            const SizedBox(width: AppDimensions.spacingXs),
                            SonoritizIconButton(
                              icon: Icons.skip_next_rounded,
                              tooltip: "Suivant",
                              color: colorScheme.onSurface,
                              onPressed: () => context.read<PlayerCubit>().playNext(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().slideY(
            begin: 1.0, 
            end: 0, 
            duration: AppAnimations.normal, 
            curve: AppAnimations.decelerate
          ),
        );
      },
    );
  }
}
