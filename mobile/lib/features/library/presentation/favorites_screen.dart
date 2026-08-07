import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import 'cubit/library_ui_cubit.dart';
import '../../../core/widgets/track_grid_view.dart';

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
      backgroundColor: Colors.transparent, // Background handled by parent
      body: BlocBuilder<LibraryUiCubit, LibraryUiState>(
        builder: (context, uiState) {
          return CustomScrollView(
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
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${favorites.length} titres • Tu adores ça",
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Lecture aléatoire
                            final shuffled = List<TrackModel>.from(favorites)..shuffle();
                            context.read<PlayerCubit>().playTrack(shuffled.first, queue: shuffled);
                          },
                          icon: const Icon(Icons.shuffle_rounded, color: Colors.white),
                          label: const Text("Lecture Aléatoire", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 8,
                            shadowColor: AppColors.primary.withOpacity(0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          ),
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              TrackGridView(
                tracks: favorites,
                viewMode: uiState.getViewModeFor('favorites'),
                sortMode: uiState.getSortModeFor('favorites'),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}
