import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_animations.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import 'cubit/library_ui_cubit.dart';
import '../../../core/widgets/track_grid_view.dart';

class FavoritesScreen extends StatelessWidget {
  final List<TrackModel> favorites;

  const FavoritesScreen({Key? key, required this.favorites}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacingXl),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite_border_rounded, size: 64, color: colorScheme.onSurfaceVariant),
            ).animate().scale(delay: AppAnimations.normal, duration: AppAnimations.slow, curve: Curves.easeOutBack),
            const SizedBox(height: AppDimensions.spacingXl),
            Text(
              "Aucun favori pour l'instant",
              style: textTheme.titleLarge,
            ).animate().fadeIn(delay: AppAnimations.slow),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              "Explore l'Accueil pour en ajouter !",
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ).animate().fadeIn(delay: AppAnimations.slow),
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
                  padding: const EdgeInsets.all(AppDimensions.spacingXl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Titres Likés",
                        style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        "${favorites.length} titres • Tu adores ça",
                        style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppDimensions.spacingXl),
                      ElevatedButton.icon(
                        onPressed: () {
                          final shuffled = List<TrackModel>.from(favorites)..shuffle();
                          context.read<PlayerCubit>().playTrack(shuffled.first, queue: shuffled);
                        },
                        icon: Icon(Icons.shuffle_rounded, color: colorScheme.onPrimary),
                        label: Text("Lecture Aléatoire", style: TextStyle(color: colorScheme.onPrimary)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
                        ),
                      ).animate().fadeIn(delay: AppAnimations.normal).slideY(begin: 0.2),
                      const SizedBox(height: AppDimensions.spacingSm),
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
