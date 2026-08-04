import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/player_cubit.dart';
import '../cubit/player_state.dart';

class QueueBottomSheet extends StatelessWidget {
  const QueueBottomSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerCubit, PlayerState>(
      builder: (context, state) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40.0, sigmaY: 40.0),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
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

                              return Container(
                                key: ValueKey('${track.id}_${track.hashCode}'),
                                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? AppColors.primary.withOpacity(0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isCurrent
                                      ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 1)
                                      : Border.all(color: Colors.transparent, width: 1),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: track.coverUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: track.coverUrl,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 48,
                                            height: 48,
                                            color: Colors.white.withOpacity(0.1),
                                            child: const Icon(Icons.music_note, color: Colors.white70),
                                          ),
                                  ),
                                  title: Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isCurrent ? AppColors.primary : Colors.white,
                                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      track.artistName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isCurrent ? AppColors.primary.withOpacity(0.8) : Colors.white.withOpacity(0.6),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  trailing: isCurrent && state.isPlaying
                                      ? const Icon(Icons.equalizer_rounded, color: AppColors.primary)
                                          .animate(onPlay: (controller) => controller.repeat())
                                          .shimmer(duration: 1000.ms)
                                      : ReorderableDragStartListener(
                                          index: index,
                                          child: Icon(Icons.drag_handle_rounded, color: Colors.white.withOpacity(0.3)),
                                        ),
                                  onTap: () {
                                    context.read<PlayerCubit>().skipToQueueItem(index);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
