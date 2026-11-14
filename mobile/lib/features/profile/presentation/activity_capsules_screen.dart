import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artist_name_display.dart';
import '../../../core/widgets/sonoritiz_artwork.dart';
import '../../../core/widgets/sonoritiz_dynamic_background.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../library/data/repositories/library_repository.dart';
import '../../library/presentation/cubit/library_cubit.dart';
import '../../library/presentation/cubit/library_state.dart';
import '../../offline/presentation/cubit/download_cubit.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/superlike_cubit.dart';

/// Sous-page Profil 2 : Capsules & Temps Forts
/// Regroupe les collections clés (Albums favoris, Superlikes, Sons likés, Playlists),
/// le fil chronologique récent et la disponibilité hors-ligne dans le style épuré de Profil.
class ActivityCapsulesScreen extends StatelessWidget {
  const ActivityCapsulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    final qualityLabel = _formatQualityLabel(storage.streamingQuality);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SonoritizDynamicBackground(
        child: SafeArea(
          bottom: false,
          child: BlocBuilder<LibraryCubit, LibraryState>(
            builder: (context, libState) {
              final slState = context.watch<SuperlikeCubit>().state;
              final dlState = context.watch<DownloadCubit>().state;

              final favorites = libState is LibraryLoaded
                  ? libState.favorites
                  : <TrackModel>[];
              final favoriteAlbums = libState is LibraryLoaded
                  ? libState.favoriteAlbums
                  : <FavoriteAlbumModel>[];
              final playlists = libState is LibraryLoaded
                  ? libState.playlists
                  : <PlaylistModel>[];
              final history = libState is LibraryLoaded
                  ? libState.history
                  : <HistoryModel>[];
              final superlikes = slState.tracks;
              final offlineCount =
                  dlState is DownloadStateData ? dlState.downloadedIds.length : 0;

              final recentHistoryTracks = history
                  .map((h) => h.track)
                  .whereType<TrackModel>()
                  .take(8)
                  .toList();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => context.pop(),
                          ),
                          const Expanded(
                            child: SonoritizPageTitle(
                              title: 'Capsules & Fil',
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 1. Capsules de collection (liens directs vers les rubriques dédiées)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Capsules de collection',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Accès rapide à vos repères enregistrés',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.48),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _CapsuleRow(
                            icon: Icons.album_rounded,
                            title: 'Albums favoris',
                            countText: '${favoriteAlbums.length}',
                            subtitle: favoriteAlbums.isNotEmpty
                                ? 'Dernier : ${favoriteAlbums.first.title}'
                                : 'Aucun album aimé pour l’instant',
                            onTap: () => context.push('/favorites/albums'),
                          ),
                          _hairline(),
                          _CapsuleRow(
                            icon: Icons.favorite_rounded,
                            title: 'Sons likés',
                            countText: '${favorites.length}',
                            subtitle: favorites.isNotEmpty
                                ? 'Dernier : ${favorites.first.title}'
                                : 'Votre sélection de titres aimés',
                            onTap: () => context.push('/favorites/tracks'),
                          ),
                          _hairline(),
                          _CapsuleRow(
                            icon: Icons.local_fire_department_rounded,
                            title: 'Sonoritiz Superlikés',
                            countText: '${superlikes.length}/20',
                            subtitle: superlikes.isNotEmpty
                                ? 'Coups de cœur absolus en rotation'
                                : 'Ajoutez jusqu’à 20 coups de cœur majeurs',
                            onTap: () => context.push('/favorites/superlikes'),
                          ),
                          _hairline(),
                          _CapsuleRow(
                            icon: Icons.queue_music_rounded,
                            title: 'Playlists personnelles',
                            countText: '${playlists.length}',
                            subtitle: playlists.isNotEmpty
                                ? playlists.take(2).map((p) => p.name).join(' · ')
                                : 'Créez votre première playlist',
                            onTap: () => context.push('/playlists_list'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Albums favoris en coup d'œil
                  if (favoriteAlbums.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                children: [
                                  const Text(
                                    'Albums gardés',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () =>
                                        context.push('/favorites/albums'),
                                    child: Text(
                                      'Voir tout ›',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 164,
                              child: ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: favoriteAlbums.take(10).length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 14),
                                itemBuilder: (context, index) {
                                  final album = favoriteAlbums[index];
                                  return GestureDetector(
                                    onTap: () => context.push(
                                      '/album',
                                      extra: album.toRouteExtra(),
                                    ),
                                    child: SizedBox(
                                      width: 118,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: SonoritizArtwork(
                                              imageUrl: album.coverUrl,
                                              width: 118,
                                              height: 118,
                                              borderRadius: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            album.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            album.artistName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.48),
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
                          ],
                        ),
                      ),
                    ),

                  // 3. Fil d'écoute récent (historique dédupliqué du plus récent)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Fil d’écoute récent',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ),
                              if (recentHistoryTracks.isNotEmpty)
                                ElevatedButton(
                                  onPressed: () {
                                    context.read<PlayerCubit>().playTrack(
                                          recentHistoryTracks.first,
                                          queue: recentHistoryTracks,
                                          source: 'Capsules Récentes',
                                        );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Reprendre',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (recentHistoryTracks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Vos dernières écoutes apparaîtront ici dans l’ordre exact de passage.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          else
                            ...List.generate(recentHistoryTracks.length, (i) {
                              final track = recentHistoryTracks[i];
                              final rawItem = history[i];
                              final when = _formatRelativeTime(rawItem.playedAt);
                              final isLast =
                                  i == recentHistoryTracks.length - 1;
                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      context.read<PlayerCubit>().playTrack(
                                            track,
                                            queue: recentHistoryTracks,
                                            source: 'Fil d’écoute',
                                          );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: SonoritizArtwork(
                                              imageUrl: track.coverUrl,
                                              width: 46,
                                              height: 46,
                                              borderRadius: 10,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  track.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                ArtistNameDisplay(
                                                  artistName: track.artistName,
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.48),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (when.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              when,
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.38),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!isLast) _hairline(),
                                ],
                              );
                            }),
                        ],
                      ),
                    ),
                  ),

                  // 4. État technique rapide (Hors-ligne & Audio)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Disponibilité & Qualité',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _CapsuleRow(
                            icon: Icons.download_done_rounded,
                            title: 'Réserve hors-ligne',
                            countText: '$offlineCount',
                            subtitle:
                                'Morceaux accessibles sans connexion · Gérer le stockage',
                            onTap: () => context.push('/storage-settings'),
                          ),
                          _hairline(),
                          _CapsuleRow(
                            icon: Icons.graphic_eq_rounded,
                            title: 'Rendu acoustique actif',
                            countText: storage.audioPreset,
                            subtitle: 'Débit sélectionné : $qualityLabel',
                            onTap: () => context.push('/audio-settings'),
                          ),
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
  }

  static Widget _hairline() {
    return Divider(
      height: 1,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }

  static String _formatQualityLabel(String id) {
    switch (id) {
      case 'hifi':
        return 'Studio Hi-Fi';
      case 'haute':
        return '320 kbps';
      case 'economie':
        return '96 kbps';
      default:
        return '160 kbps';
    }
  }

  static String _formatRelativeTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}

class _CapsuleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String countText;
  final VoidCallback onTap;

  const _CapsuleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.countText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.78),
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              countText,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
