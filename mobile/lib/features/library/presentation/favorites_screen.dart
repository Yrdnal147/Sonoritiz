import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sonoritiz_artwork.dart';
import '../../../core/widgets/superlike_torch_badge.dart';
import '../../../core/widgets/track_grid_view.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/superlike_cubit.dart';
import '../../player/presentation/cubit/superlike_state.dart';
import '../data/repositories/library_repository.dart';
import 'cubit/library_cubit.dart';
import 'cubit/library_state.dart';
import 'cubit/library_ui_cubit.dart';

class FavoritesScreen extends StatelessWidget {
  final List<TrackModel> favorites;

  const FavoritesScreen({Key? key, required this.favorites}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocBuilder<LibraryUiCubit, LibraryUiState>(
        builder: (context, uiState) {
          final query = LibraryUiCubit.normalizeForSearch(uiState.searchQuery);
          final hasActiveQuery = query.isNotEmpty;

          return BlocBuilder<LibraryCubit, LibraryState>(
            builder: (context, libState) {
              final favoriteAlbums = libState is LibraryLoaded
                  ? libState.favoriteAlbums
                  : const <FavoriteAlbumModel>[];
              final allFavorites = libState is LibraryLoaded
                  ? libState.favorites
                  : favorites;

              return BlocBuilder<SuperlikeCubit, SuperlikeState>(
                builder: (context, superState) {
                  final superlikes = superState.tracks;

                  if (hasActiveQuery) {
                    final matchingAlbums = favoriteAlbums
                        .where((a) =>
                            LibraryUiCubit.normalizeForSearch(a.title).contains(query) ||
                            LibraryUiCubit.normalizeForSearch(a.artistName).contains(query))
                        .toList();

                    if (favorites.isEmpty && matchingAlbums.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 46,
                                color: colorScheme.primary.withValues(alpha: 0.8),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Aucun favori trouvé pour « ${uiState.searchQuery.trim()} »",
                                textAlign: TextAlign.center,
                                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                onPressed: () => context.read<LibraryUiCubit>().closeSearch(),
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                label: const Text("Effacer la recherche"),
                                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        if (matchingAlbums.isNotEmpty)
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 146,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                scrollDirection: Axis.horizontal,
                                itemCount: matchingAlbums.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, idx) {
                                  final album = matchingAlbums[idx];
                                  return GestureDetector(
                                    onTap: () => context.push('/album', extra: album.toRouteExtra()),
                                    child: SizedBox(
                                      width: 108,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SonoritizArtwork(
                                            imageUrl: album.coverUrl,
                                            width: 96,
                                            height: 96,
                                            borderRadius: 12,
                                            cacheMaxDimension: 260,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            album.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        if (favorites.isNotEmpty)
                          TrackGridView(
                            key: ValueKey('fav_search_${favorites.length}'),
                            tracks: favorites,
                            viewMode: uiState.getViewModeFor('favorites'),
                            sortMode: uiState.getSortModeFor('favorites'),
                            playbackSource: 'vos favoris',
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 130)),
                      ],
                    );
                  }

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Collections de cœur",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _FavoriteRubricTile(
                                title: "Albums favoris",
                                subtitle: favoriteAlbums.isEmpty
                                    ? "Aucun album enregistré pour le moment"
                                    : "${favoriteAlbums.length} ${favoriteAlbums.length > 1 ? 'albums complets' : 'album complet'}",
                                coverUrl: favoriteAlbums.isNotEmpty ? favoriteAlbums.first.coverUrl : '',
                                fallbackIcon: Icons.album_rounded,
                                accentColor: const Color(0xFFFFB74D),
                                onTap: () => context.push('/favorites/albums'),
                                onQuickPlay: (favoriteAlbums.isNotEmpty && favoriteAlbums.first.tracks.isNotEmpty)
                                    ? () {
                                        final album = favoriteAlbums.first;
                                        context.read<PlayerCubit>().playTrack(
                                              album.tracks.first,
                                              queue: album.tracks,
                                              source: "${album.artistName} • ${album.title}",
                                            );
                                      }
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _FavoriteRubricTile(
                                title: "Sons likés",
                                subtitle: allFavorites.isEmpty
                                    ? "Ajoute tes premiers titres favoris"
                                    : "${allFavorites.length} ${allFavorites.length > 1 ? 'titres enregistrés' : 'titre enregistré'}",
                                coverUrl: allFavorites.isNotEmpty ? allFavorites.first.coverUrl : '',
                                fallbackIcon: Icons.favorite_rounded,
                                accentColor: AppColors.primary,
                                onTap: () => context.push('/favorites/tracks'),
                                onQuickPlay: allFavorites.isNotEmpty
                                    ? () {
                                        context.read<PlayerCubit>().playTrack(
                                              allFavorites.first,
                                              queue: allFavorites,
                                              source: 'vos sons likés',
                                            );
                                      }
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _FavoriteRubricTile(
                                title: "Sonoritiz Superlikés",
                                subtitle: superlikes.isEmpty
                                    ? "Jusqu'à ${SuperlikeCubit.maxSuperlikes} coups de cœur vibrants"
                                    : "${superlikes.length} / ${SuperlikeCubit.maxSuperlikes} titres d'élite",
                                coverUrl: superlikes.isNotEmpty ? superlikes.first.coverUrl : '',
                                fallbackIcon: Icons.local_fire_department_rounded,
                                customBadge: const SuperlikeTorchBadge(
                                  size: TorchBadgeSize.small,
                                  showBackground: false,
                                ),
                                accentColor: const Color(0xFFFF6D00),
                                onTap: () => context.push('/favorites/superlikes'),
                                onQuickPlay: superlikes.isNotEmpty
                                    ? () {
                                        context.read<PlayerCubit>().playTrack(
                                              superlikes.first,
                                              queue: superlikes,
                                              source: 'vos Sonoritiz Superlikés',
                                            );
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (favoriteAlbums.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                            child: Row(
                              children: [
                                Text(
                                  "Derniers albums aimés",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => context.push('/favorites/albums'),
                                  child: const Text(
                                    "Tout voir",
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 164,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: favoriteAlbums.take(10).length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (context, idx) {
                                final album = favoriteAlbums[idx];
                                return GestureDetector(
                                  onTap: () => context.push('/album', extra: album.toRouteExtra()),
                                  child: SizedBox(
                                    width: 118,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SonoritizArtwork(
                                          imageUrl: album.coverUrl,
                                          width: 118,
                                          height: 118,
                                          borderRadius: 14,
                                          cacheMaxDimension: 300,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          album.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          album.artistName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.55),
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      if (allFavorites.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                            child: Row(
                              children: [
                                Text(
                                  "Aperçu des sons likés",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => context.push('/favorites/tracks'),
                                  child: const Text(
                                    "Tout voir",
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        TrackGridView(
                          key: const ValueKey('favorites_recent_preview'),
                          tracks: allFavorites.take(6).toList(),
                          viewMode: ViewMode.list,
                          sortMode: SortMode.recent,
                          playbackSource: 'vos sons likés',
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 130)),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FavoriteRubricTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String coverUrl;
  final IconData fallbackIcon;
  final Widget? customBadge;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback? onQuickPlay;

  const _FavoriteRubricTile({
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.fallbackIcon,
    required this.accentColor,
    required this.onTap,
    this.customBadge,
    this.onQuickPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (coverUrl.isNotEmpty)
                      SonoritizArtwork(
                        imageUrl: coverUrl,
                        width: 60,
                        height: 60,
                        borderRadius: 14,
                        cacheMaxDimension: 200,
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: accentColor.withValues(alpha: 0.16),
                        ),
                        child: Center(
                          child: customBadge ??
                              Icon(fallbackIcon, color: accentColor, size: 28),
                        ),
                      ),
                    if (coverUrl.isNotEmpty && customBadge != null)
                      Positioned(
                        right: 3,
                        bottom: 3,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            shape: BoxShape.circle,
                          ),
                          child: customBadge!,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onQuickPlay != null) ...[
                GestureDetector(
                  onTap: onQuickPlay,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
