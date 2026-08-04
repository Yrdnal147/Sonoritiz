import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../offline/presentation/cubit/download_cubit.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../../core/utils/share_utils.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadCubit, DownloadState>(
      builder: (context, state) {
        if (state is! DownloadStateData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (state.offlineTracks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_done, size: 80, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  "Aucun téléchargement",
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.offlineTracks.length,
          itemBuilder: (context, index) {
            final offlineTrack = state.offlineTracks[index];
            final track = offlineTrack.track;

            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: offlineTrack.localCoverPath.isNotEmpty && File(offlineTrack.localCoverPath).existsSync()
                    ? Image.file(
                        File(offlineTrack.localCoverPath),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : CachedNetworkImage(
                        imageUrl: track.coverUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          width: 50,
                          height: 50,
                          color: AppColors.surface,
                          child: const Icon(Icons.music_note, color: AppColors.textSecondary),
                        ),
                      ),
              ),
              title: Text(
                track.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                track.artistName,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white54),
                color: AppColors.surface,
                onSelected: (value) {
                  if (value == 'share') {
                    ShareUtils.shareTrack(track);
                  } else if (value == 'delete') {
                    context.read<DownloadCubit>().removeDownload(track.id);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share_rounded, color: Colors.white70, size: 20),
                        SizedBox(width: 12),
                        Text("Partager", style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                        SizedBox(width: 12),
                        Text("Supprimer", style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () {
                // Play all downloads starting from this index
                final playerCubit = context.read<PlayerCubit>();
                final queue = state.offlineTracks.map((e) => e.track).toList();
                
                // On simule une lecture de playlist
                // Comme le track_id est le même, l'AudioHandler va le trouver en local !
                for (var i = 0; i < queue.length; i++) {
                   if (i == 0) {
                     // Empty logic to reset if needed
                   }
                   playerCubit.addToQueue(queue[i]);
                }
                playerCubit.skipToQueueItem(playerCubit.state.queue.length - queue.length + index);
              },
            );
          },
        );
      },
    );
  }
}
