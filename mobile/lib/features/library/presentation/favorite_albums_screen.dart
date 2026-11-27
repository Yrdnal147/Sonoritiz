import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/collection_context_menu.dart';
import '../../../core/widgets/sonoritiz_artwork.dart';
import '../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/player_state.dart';
import '../data/repositories/library_repository.dart';
import 'cubit/library_cubit.dart';
import 'cubit/library_state.dart';

class FavoriteAlbumsScreen extends StatelessWidget {
  const FavoriteAlbumsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, state) {
        final albums = state is LibraryLoaded
            ? state.favoriteAlbums
            : const <FavoriteAlbumModel>[];
        final heroCover = albums.isNotEmpty ? albums.first.coverUrl : '';

        return Scaffold(
          backgroundColor: Colors.black,
          body: SonoritizCoverAtmosphere(
            coverUrl: heroCover,
            child: SafeArea(
              child: Column(
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
                      title: 'Albums favoris',
                      fontSize: 22,
                    ),
                  ),
                  Expanded(
                    child: albums.isEmpty
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
                                      Icons.album_rounded,
                                      size: 42,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    "Aucun album favori",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Aime un album entier depuis sa page pour le retrouver ici avec tous ses morceaux likés automatiquement.",
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
                        : CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                                  child: Text(
                                    "${albums.length} ${albums.length > 1 ? 'albums enregistrés' : 'album enregistré'}",
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.58),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: ResponsiveUtils.adaptiveGridColumns(
                                      MediaQuery.sizeOf(context).width,
                                      narrow: 2,
                                      mobile: 2,
                                      medium: 3,
                                      expanded: 4,
                                      ultraWide: 5,
                                    ),
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 18,
                                    childAspectRatio: 0.72,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final album = albums[index];
                                      return _FavoriteAlbumCard(album: album);
                                    },
                                    childCount: albums.length,
                                  ),
                                ),
                              ),
                            ],
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

class _FavoriteAlbumCard extends StatelessWidget {
  final FavoriteAlbumModel album;

  const _FavoriteAlbumCard({required this.album});

  bool _isAlbumActive(PlayerState pState) {
    final cur = pState.currentTrack;
    if (cur == null) return false;
    final titleLower = album.title.trim().toLowerCase();
    if (titleLower.isEmpty) return false;
    if (cur.albumName.trim().toLowerCase() == titleLower) return true;
    final src = pState.playbackSource.trim().toLowerCase();
    return src.contains(titleLower);
  }

  @override
  Widget build(BuildContext context) {
    final trackCount = album.tracks.isNotEmpty ? album.tracks.length : album.tracksCount;

    return BlocSelector<PlayerCubit, PlayerState, (bool, bool)>(
      selector: (pState) => (_isAlbumActive(pState), pState.isPlaying),
      builder: (context, activeTuple) {
        final bool isActive = activeTuple.$1;
        final bool isPlaying = activeTuple.$2;

        return GestureDetector(
          onTap: () => context.push('/album', extra: album.toRouteExtra()),
          onLongPress: () => CollectionContextMenu.showForAlbum(
            context,
            albumId: album.id,
            title: album.title,
            artistName: album.artistName,
            coverUrl: album.coverUrl,
            year: album.year,
            preloadedTracks: album.tracks.isNotEmpty ? album.tracks : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      padding:
                          isActive ? const EdgeInsets.all(2) : EdgeInsets.zero,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(16 + (isActive ? 2 : 0)),
                        border: isActive
                            ? Border.all(color: AppColors.primary, width: 2.0)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: isActive
                                ? AppColors.primary.withValues(alpha: 0.36)
                                : Colors.black.withValues(alpha: 0.35),
                            blurRadius: isActive ? 16 : 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: SonoritizArtwork(
                        imageUrl: album.coverUrl,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 16,
                        cacheMaxDimension: 420,
                      ),
                    ),
                    if (isActive)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPlaying
                                    ? Icons.graphic_eq_rounded
                                    : Icons.pause_rounded,
                                color: Colors.black,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                "EN COURS",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () async {
                          await context
                              .read<LibraryCubit>()
                              .toggleFavoriteAlbum(
                                albumId: album.id,
                                title: album.title,
                                artistName: album.artistName,
                                coverUrl: album.coverUrl,
                                year: album.year,
                                albumTracks: album.tracks,
                              );
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.black,
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                    if (album.tracks.isNotEmpty)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: GestureDetector(
                          onTap: () {
                            context.read<PlayerCubit>().playTrack(
                                  album.tracks.first,
                                  queue: album.tracks,
                                  source:
                                      "${album.artistName} • ${album.title}",
                                );
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              isActive && isPlaying
                                  ? Icons.graphic_eq_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? AppColors.primary : Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  album.artistName,
                  if (trackCount > 0) '$trackCount titres',
                  if (album.year.isNotEmpty) album.year,
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
