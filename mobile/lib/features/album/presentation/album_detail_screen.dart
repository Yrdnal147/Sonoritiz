import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/player_state.dart';

class AlbumDetailScreen extends StatelessWidget {
  final String albumTitle;
  final String artistName;
  final String coverUrl;
  final List<TrackModel> tracks;

  const AlbumDetailScreen({
    Key? key,
    required this.albumTitle,
    required this.artistName,
    required this.coverUrl,
    this.tracks = const [],
  }) : super(key: key);

  String _formatSeconds(int seconds) {
    final mins = seconds ~/ 60;
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final coverWidth = MediaQuery.of(context).size.width * 0.4;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Header cover
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: coverUrl.isNotEmpty
                    ? CachedNetworkImage(imageUrl: coverUrl, width: coverWidth, height: coverWidth, fit: BoxFit.cover)
                    : Container(width: coverWidth, height: coverWidth, color: AppColors.surface, child: const Icon(Icons.album, size: 64, color: Colors.white54)),
              ),
            ),
            const SizedBox(height: 16),
            Text(albumTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(artistName, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 16),

            // Play album button
            ElevatedButton.icon(
              onPressed: () {
                if (tracks.isNotEmpty) {
                  context.read<PlayerCubit>().playTrack(tracks.first, queue: tracks);
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text("Tout écouter"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(180, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.white12),

            // Numbered track list
            BlocBuilder<PlayerCubit, PlayerState>(
              builder: (context, state) {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final isPlayingThis = state.currentTrack?.id == track.id;

                    return Container(
                      color: isPlayingThis ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                      child: ListTile(
                        leading: Text(
                          "${index + 1}",
                          style: TextStyle(
                            color: isPlayingThis ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        title: Text(
                          track.title,
                          style: TextStyle(
                            color: isPlayingThis ? AppColors.primary : Colors.white,
                            fontWeight: isPlayingThis ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Text(
                          _formatSeconds(track.durationSeconds),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        onTap: () {
                          context.read<PlayerCubit>().playTrack(track, queue: tracks);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
