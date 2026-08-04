import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../data/repositories/library_repository.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final PlaylistModel playlist;

  const PlaylistDetailScreen({Key? key, required this.playlist}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tracks = playlist.tracks;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // --- EN-TÊTE AVEC EFFET DE COLLAPSE ---
          SliverAppBar(
            backgroundColor: AppColors.background,
            expandedHeight: 220,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withOpacity(0.4),
                      AppColors.background,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Icône de la playlist
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 2),
                        ),
                        child: const Icon(Icons.queue_music_rounded, size: 40, color: AppColors.primary),
                      ).animate().fadeIn(duration: 400.ms).scaleXY(begin: 0.8, end: 1.0),
                      const SizedBox(height: 16),
                      // Nom de la playlist en orange
                      Text(
                        playlist.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 6),
                      // Nombre de sons
                      Text(
                        "${tracks.length} morceau${tracks.length != 1 ? 'x' : ''}",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- BOUTON LECTURE ---
          if (tracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<PlayerCubit>().playTrack(tracks.first, queue: tracks);
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text("Tout lire", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 4,
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
            ),

          // --- LISTE DES SONS ---
          if (tracks.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_off_rounded, size: 64, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      "Cette playlist est vide",
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ajoute des sons depuis le lecteur",
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = tracks[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: track.coverUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: track.coverUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => Container(
                                width: 52,
                                height: 52,
                                color: AppColors.surface,
                                child: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                            )
                          : Container(
                              width: 52,
                              height: 52,
                              color: AppColors.surface,
                              child: const Icon(Icons.music_note, color: Colors.white54),
                            ),
                    ),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 32),
                      onPressed: () {
                        context.read<PlayerCubit>().playTrack(track, queue: tracks);
                      },
                    ),
                    onTap: () {
                      context.read<PlayerCubit>().playTrack(track, queue: tracks);
                    },
                  ).animate().fadeIn(delay: (100 + index * 50).ms).slideX(begin: 0.05, end: 0);
                },
                childCount: tracks.length,
              ),
            ),

          // Un peu d'espace en bas
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
