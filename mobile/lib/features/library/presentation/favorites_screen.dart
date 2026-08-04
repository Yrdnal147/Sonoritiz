import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import 'cubit/library_cubit.dart';
import '../../../core/utils/share_utils.dart';

class FavoritesScreen extends StatelessWidget {
  final List<TrackModel> favorites;

  const FavoritesScreen({Key? key, required this.favorites}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_border_rounded, size: 64, color: Colors.white54),
            ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            const Text(
              "Aucun favori pour l'instant",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 8),
            Text(
              "Explore l'Accueil pour en ajouter !",
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by parent (LibraryScreen)
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Titres Likés",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn().slideX(begin: -0.1),
                  const SizedBox(height: 4),
                  Text(
                    "${favorites.length} morceaux",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final shuffled = List<TrackModel>.from(favorites)..shuffle();
                            if (shuffled.isNotEmpty) {
                              context.read<PlayerCubit>().playTrack(shuffled.first, queue: shuffled);
                            }
                          },
                          icon: const Icon(Icons.shuffle_rounded, color: Colors.white),
                          label: const Text(
                            "Lecture aléatoire",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: AppColors.primary.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                          onPressed: () {
                            if (favorites.isNotEmpty) {
                              context.read<PlayerCubit>().playTrack(favorites.first, queue: favorites);
                            }
                          },
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final track = favorites[index];
                return Dismissible(
                  key: Key(track.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                  ),
                  onDismissed: (_) {
                    context.read<LibraryCubit>().removeFavorite(track.id);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: track.coverUrl.isNotEmpty
                            ? CachedNetworkImage(imageUrl: track.coverUrl, width: 50, height: 50, fit: BoxFit.cover)
                            : Container(width: 50, height: 50, color: Colors.white12, child: const Icon(Icons.music_note_rounded, color: Colors.white54)),
                      ),
                      title: Text(
                        track.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          track.artistName,
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
                        color: AppColors.surface,
                        onSelected: (value) {
                          if (value == 'share') {
                            ShareUtils.shareTrack(track);
                          } else if (value == 'remove') {
                            context.read<LibraryCubit>().removeFavorite(track.id);
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
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                SizedBox(width: 12),
                                Text("Retirer des favoris", style: TextStyle(color: AppColors.error)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        context.read<PlayerCubit>().playTrack(track, queue: favorites);
                      },
                    ),
                  ).animate().fadeIn(delay: Duration(milliseconds: 300 + (index * 50))).slideX(begin: 0.1),
                );
              },
              childCount: favorites.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Espace pour le lecteur global
        ],
      ),
    );
  }
}
