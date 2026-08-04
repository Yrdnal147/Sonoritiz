import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../data/repositories/library_repository.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../../core/utils/share_utils.dart';

class HistoryScreen extends StatelessWidget {
  final List<HistoryModel> history;

  const HistoryScreen({Key? key, required this.history}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              "Ton historique d'écoute apparaîtra ici",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final item = history[index];
          final track = item.track;
          if (track == null) return const SizedBox.shrink();

          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: track.coverUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: track.coverUrl, width: 44, height: 44, fit: BoxFit.cover)
                  : Container(width: 44, height: 44, color: AppColors.surface, child: const Icon(Icons.music_note, color: Colors.white70)),
            ),
            title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(track.artistName, style: const TextStyle(color: AppColors.textSecondary)),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              color: AppColors.surface,
              onSelected: (value) {
                if (value == 'share') {
                  ShareUtils.shareTrack(track);
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
              ],
            ),
            onTap: () {
              context.read<PlayerCubit>().playTrack(track);
            },
          );
        },
      ),
    );
  }
}
