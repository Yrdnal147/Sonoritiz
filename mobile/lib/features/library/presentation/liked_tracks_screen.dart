import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../core/widgets/sonoritiz_fast_scrollbar.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../../core/widgets/track_grid_view.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import 'cubit/library_cubit.dart';
import 'cubit/library_state.dart';
import 'cubit/library_ui_cubit.dart';

class LikedTracksScreen extends StatelessWidget {
  const LikedTracksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, libState) {
        final favorites = libState is LibraryLoaded
            ? libState.favorites
            : const <TrackModel>[];
        final heroCover = favorites.isNotEmpty ? favorites.first.coverUrl : '';

        return Scaffold(
          backgroundColor: Colors.black,
          body: SonoritizCoverAtmosphere(
            coverUrl: heroCover,
            child: SafeArea(
              child: BlocBuilder<LibraryUiCubit, LibraryUiState>(
                builder: (context, uiState) {
                  final sortMode = uiState.getSortModeFor('favorites');
                  final viewMode = uiState.getViewModeFor('favorites');
                  final sortedFavorites = TrackGridView.sortTracks(favorites, sortMode);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => context.pop(),
                        ),
                        title: const SonoritizPageTitle(
                          title: 'Sons likés',
                          fontSize: 22,
                        ),
                        actions: [
                          IconButton(
                            tooltip: sortMode == SortMode.recent
                                ? 'Tri : Plus récent'
                                : 'Tri : A-Z',
                            icon: Icon(
                              sortMode == SortMode.recent
                                  ? Icons.schedule_rounded
                                  : Icons.sort_by_alpha_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => context.read<LibraryUiCubit>().setSortMode(
                                  sortMode == SortMode.recent
                                      ? SortMode.alpha
                                      : SortMode.recent,
                                  tabKey: 'favorites',
                                ),
                          ),
                          PopupMenuButton<ViewMode>(
                            icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
                            color: const Color(0xFF181820),
                            onSelected: (mode) => context
                                .read<LibraryUiCubit>()
                                .setViewMode(mode, tabKey: 'favorites'),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: ViewMode.list, child: Text('Liste', style: TextStyle(color: Colors.white))),
                              PopupMenuItem(value: ViewMode.listCompact, child: Text('Liste compacte', style: TextStyle(color: Colors.white))),
                              PopupMenuItem(value: ViewMode.gridMedium, child: Text('Grille', style: TextStyle(color: Colors.white))),
                              PopupMenuItem(value: ViewMode.cards, child: Text('Cartes', style: TextStyle(color: Colors.white))),
                            ],
                          ),
                        ],
                      ),
                      Expanded(
                        child: sortedFavorites.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 36),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 88,
                                        height: 88,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.favorite_border_rounded,
                                          size: 42,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      const Text(
                                        "Aucun son liké",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Like tes titres favoris ou un album entier pour constituer ta collection.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 13.5,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SonoritizFastScrollbar(
                                itemCount: sortedFavorites.length,
                                bottomMargin: 120,
                                labelBuilder: (idx) {
                                  final t = sortedFavorites[idx];
                                  if (sortMode == SortMode.alpha && t.title.trim().isNotEmpty) {
                                    final c = t.title.trim()[0].toUpperCase();
                                    return RegExp(r'[A-ZÀ-Ÿ0-9]').hasMatch(c) ? c : '#';
                                  }
                                  return '${idx + 1}';
                                },
                                child: CustomScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  slivers: [
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                                        child: Row(
                                          children: [
                                            Text(
                                              "${sortedFavorites.length} ${sortedFavorites.length > 1 ? 'titres' : 'titre'}",
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.6),
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const Spacer(),
                                            GestureDetector(
                                              onTap: () {
                                                final shuffled = List<TrackModel>.from(sortedFavorites)..shuffle();
                                                context.read<PlayerCubit>().playTrack(
                                                      shuffled.first,
                                                      queue: shuffled,
                                                      source: 'vos sons likés',
                                                    );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(24),
                                                  border: Border.all(
                                                    color: Colors.white.withValues(alpha: 0.16),
                                                  ),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.shuffle_rounded, color: Colors.white, size: 18),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      "Aléatoire",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13.5,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            GestureDetector(
                                              onTap: () {
                                                context.read<PlayerCubit>().playTrack(
                                                      sortedFavorites.first,
                                                      queue: sortedFavorites,
                                                      source: 'vos sons likés',
                                                    );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius: BorderRadius.circular(24),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      "Lire",
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    TrackGridView(
                                      key: ValueKey('liked_${viewMode.name}_${sortMode.name}'),
                                      tracks: favorites,
                                      viewMode: viewMode,
                                      sortMode: sortMode,
                                      playbackSource: 'vos sons likés',
                                    ),
                                    const SliverToBoxAdapter(child: SizedBox(height: 130)),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
