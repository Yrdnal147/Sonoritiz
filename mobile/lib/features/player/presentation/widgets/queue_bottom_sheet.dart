import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/player_cubit.dart';
import '../cubit/player_state.dart';
import '../../../../core/widgets/sonoritiz_track_tile.dart';

class QueueBottomSheet extends StatelessWidget {
  const QueueBottomSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerCubit, PlayerState>(
      builder: (context, state) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: const Color(0xF7161616),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag handle
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      children: [
                        const Icon(Icons.queue_music_rounded, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          "File d'attente",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "${state.queue.length} titres",
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
                  
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withOpacity(0.1), height: 1),
                  
                  // List
                  Expanded(
                    child: state.queue.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.music_off_rounded, size: 64, color: Colors.white.withOpacity(0.2)),
                                const SizedBox(height: 16),
                                Text(
                                  "La file d'attente est vide.",
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                                ),
                              ],
                            ),
                          )
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 40.0),
                            physics: const BouncingScrollPhysics(),
                            itemCount: state.queue.length,
                            onReorder: (oldIndex, newIndex) {
                              context.read<PlayerCubit>().reorderQueue(oldIndex, newIndex);
                            },
                            proxyDecorator: (child, index, animation) {
                              return Material(
                                color: Colors.transparent,
                                elevation: 12,
                                child: child,
                              );
                            },
                            itemBuilder: (context, index) {
                              final track = state.queue[index];
                              final isCurrent = index == state.currentIndex;

                              return Column(
                                key: ValueKey('${track.id}_${track.hashCode}'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SonoritizTrackTile(
                                    track: track,
                                    queue: state.queue,
                                    trailing: isCurrent && state.isPlaying
                                        ? const Icon(Icons.equalizer_rounded, color: Colors.white)
                                            .animate(onPlay: (controller) => controller.repeat())
                                            .shimmer(duration: 1000.ms)
                                        : ReorderableDragStartListener(
                                            index: index,
                                            child: Icon(Icons.drag_handle_rounded, color: Colors.white.withValues(alpha: 0.3)),
                                          ),
                                    onTap: () {
                                      context.read<PlayerCubit>().skipToQueueItem(index);
                                    },
                                  ),
                                  // Trait gris de séparation distinct entre les sons de haut en bas
                                  Divider(
                                    color: Colors.white.withOpacity(0.14),
                                    height: 1,
                                    thickness: 0.8,
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
