import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/player_cubit.dart';
import '../cubit/player_state.dart';
import '../screens/fullscreen_player_screen.dart';
import '../../data/models/track_model.dart';

class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Le BlocSelector garantit que le widget global (et le BackdropFilter coûteux)
    // ne se reconstruit QUE lorsque la musique change, et PAS à chaque seconde !
    return BlocSelector<PlayerCubit, PlayerState, TrackModel?>(
      selector: (state) => state.currentTrack,
      builder: (context, track) {
        if (track == null) return const SizedBox.shrink();

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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05), width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      // Animated Progress Bar Background (Seul cet élément écoute la position)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          color: Colors.white.withOpacity(0.05),
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
                                    color: AppColors.primary,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(
                          children: [
                            // Cover thumbnail
                            Hero(
                              tag: 'cover_' + track.id,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: track.coverUrl.isNotEmpty
                                      ? (track.coverUrl.startsWith('file://')
                                          ? Image.file(File(track.coverUrl.replaceFirst('file://', '')), fit: BoxFit.cover)
                                          : CachedNetworkImage(
                                              imageUrl: track.coverUrl,
                                              fit: BoxFit.cover,
                                            ))
                                      : Container(color: AppColors.surfaceLight, child: const Icon(Icons.music_note, color: Colors.white54)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
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
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.artistName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            // Play/Pause button (S'actualise uniquement si le statut Play/Pause change)
                            BlocSelector<PlayerCubit, PlayerState, bool>(
                              selector: (state) => state.isPlaying,
                              builder: (context, isPlaying) {
                                return GestureDetector(
                                  onTap: () => context.read<PlayerCubit>().togglePlayPause(),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: AppColors.primary,
                                      size: 28,
                                    ),
                                  ).animate(target: isPlaying ? 1 : 0).scaleXY(end: 1.05, duration: 150.ms),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            // Next button
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 32),
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
          ).animate().slideY(begin: 1.0, end: 0, duration: 400.ms, curve: Curves.easeOutBack),
        );
      },
    );
  }
}
