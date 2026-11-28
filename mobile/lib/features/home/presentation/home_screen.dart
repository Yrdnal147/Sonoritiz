import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/services/palette_service.dart';
import '../../../core/widgets/collection_context_menu.dart';
import '../../../core/widgets/playlist_cover_mosaic.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../../core/widgets/sonoritiz_section_header.dart';
import '../../../core/widgets/sonoritiz_track_card.dart';
import '../../../core/widgets/sonoritiz_artist_circle_card.dart';
import '../../../core/widgets/sonoritiz_artwork.dart';
import '../../../core/widgets/sonoritiz_dynamic_background.dart';
import '../../../core/widgets/track_context_menu.dart';

import '../../library/data/repositories/library_repository.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/superlike_cubit.dart';
import '../../player/presentation/cubit/superlike_state.dart';
import '../../player/presentation/widgets/player_components/immersive_player_widgets.dart';
import '../../../core/widgets/superlike_torch_badge.dart';
import '../../search/presentation/widgets/voice_search_bottom_sheet.dart';
import '../data/repositories/catalog_repository.dart';

import 'cubit/home_cubit.dart';
import 'cubit/home_state.dart';
import 'widgets/home_skeleton.dart';
import 'widgets/new_releases_carousel_widget.dart';
import 'widgets/sonoritiz_home_lyrics_carousel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const _HomeScreenBody();
  }
}

class _HomeScreenBody extends StatefulWidget {
  const _HomeScreenBody({Key? key}) : super(key: key);

  @override
  State<_HomeScreenBody> createState() => _HomeScreenBodyState();
}

class _HomeScreenBodyState extends State<_HomeScreenBody> with AutomaticKeepAliveClientMixin {
  late int _lyricSeed;
  List<TrackModel> _releaseRadarTracks = const [];
  String _lastRadarArtistsSig = '';
  bool _loadingRadar = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _lyricSeed = DateTime.now().millisecondsSinceEpoch;
    final storage = StorageService();
    StorageService.recentPodcastsNotifier.value =
        storage.getRecentPodcastsRaw();
    StorageService.connectRecommendationsNotifier.value =
        storage.getConnectGuestRecommendationsRaw();
  }

  void _ensureReleaseRadarLoaded(HomeLoaded state) {
    final followed = StorageService().getFollowedArtists();
    final favNames = state.favoriteArtists
        .map((a) => (a['name'] ?? '').trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final allArtists = <String>{...followed, ...favNames}
        .where((n) => n.toLowerCase() != 'inconnu')
        .take(5)
        .toList();
    final sig = allArtists.join('|');
    if (sig.isEmpty || sig == _lastRadarArtistsSig || _loadingRadar) return;
    _lastRadarArtistsSig = sig;
    _loadingRadar = true;

    Future.microtask(() async {
      final repo = CatalogRepository();
      final List<TrackModel> collected = [];
      final Set<String> seenIds = {};
      try {
        final futures = allArtists
            .take(4)
            .map((artist) => repo.getArtistTopTracks(artist, limit: 4));
        final lists = await Future.wait(futures);
        for (final list in lists) {
          for (final t in list) {
            if (seenIds.add(t.id)) {
              collected.add(t);
            }
          }
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _releaseRadarTracks = collected;
        _loadingRadar = false;
      });
    });
  }

  String _getRandomLyricSnippet(
    List<TrackModel> favorites, {
    List<TrackModel> fallbackTracks = const [],
  }) {
    final candidates = [...favorites, ...fallbackTracks]
        .where((t) =>
            t.title.trim().isNotEmpty &&
            t.artistName.trim().isNotEmpty &&
            t.artistName.trim().toLowerCase() != 'inconnu' &&
            t.artistName.trim().toLowerCase() != 'unknown' &&
            t.artistName.trim().toLowerCase() != 'artiste inconnu')
        .toList();
    if (candidates.isEmpty) {
      return "♪ Sonoritiz — Votre musique en continu";
    }
    final random = math.Random(_lyricSeed);
    final track = candidates[random.nextInt(candidates.length)];
    final title = track.title.trim();
    final artist = track.artistName.trim();
    final snippets = [
      "\"$title\" — $artist",
      "♪ $title • $artist",
      "$artist — $title",
    ];
    return snippets[random.nextInt(snippets.length)];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SonoritizDynamicBackground(
        keepWhenPaused: true,
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            if (state is HomeLoading) {
              return const HomeSkeleton();
            }

            if (state is HomeError) {
              return _buildErrorState(context, state.message);
            }

            if (state is HomeLoaded) {
              _ensureReleaseRadarLoaded(state);
              return RefreshIndicator(
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.surface,
                onRefresh: () => context.read<HomeCubit>().loadHomeData(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildPremiumAppBar(context, state),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppDimensions.spacingSm, bottom: AppDimensions.spacingXxxl * 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Albums & Sons à venir & Sorties de la semaine (Carrousel 3D Hero)
                            const NewReleasesCarouselWidget(),
                            const SizedBox(height: AppDimensions.spacingXl),

                            // 1b. Sons à venir & Sorties de la semaine (titres récents & nouveautés)
                            if (state.newReleases.isNotEmpty) ...[
                              _buildNewReleaseTracksSection(context, state),
                              const SizedBox(height: AppDimensions.spacingXl),
                            ],

                            // 1c. Radar des Sorties (Nouveautés de vos artistes suivis)
                            _buildReleaseRadarSection(context, state),

                            // 2. Écouté récemment
                            if (state.recentlyPlayed.isNotEmpty) ...[
                              _buildRecentlyPlayedSection(context, state),
                              const SizedBox(height: AppDimensions.spacingXl),
                            ],

                            // 2b. Podcasts écoutés récemment (Gros cadres en Glassmorphism + jauge de reprise)
                            _buildRecentPodcastsGlassSection(context),

                            // 2c. Recommandation Sonoritiz Connect (uniquement si les invités ont proposé des sons)
                            _buildConnectRecommendationsSection(context),

                            // 2d. Sonoritiz Lyrics (10 sons aimés/superlikés • extraits 30s synchronisés • rotation 5 jours)
                            SonoritizHomeLyricsCarousel(
                              fallbackFavorites: state.userFavorites,
                            ),

                            // 3. Sons basés sur vos écoutes (5 playlists personnalisées 16:9, régénération 7 jours)
                            if (state.weeklyCuratedPlaylists.isNotEmpty) ...[
                              _buildWeeklyCuratedPlaylistsSection(context, state),
                              const SizedBox(height: AppDimensions.spacingXl),
                            ],

                            // 4. Sonoritiz Random (25 sons opposés avec slogan exact)
                            if (state.sonoritizRandomTracks.isNotEmpty) ...[
                              _buildSonoritizRandomSection(context, state),
                              const SizedBox(height: AppDimensions.spacingXl),
                            ],

                            // 5. Vos Sonoritiz Superlikes ! (Prioritaire si au moins 1 son superliké)
                            BlocBuilder<SuperlikeCubit, SuperlikeState>(
                              builder: (context, slState) {
                                if (slState.tracks.isEmpty) return const SizedBox.shrink();
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
                                      child: Row(
                                        children: [
                                          const SuperlikeTorchBadge(
                                            size: TorchBadgeSize.small,
                                            showBackground: true,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            "Vos Sonoritiz Superlikes !",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF9100).withOpacity(0.18),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFFFF9100).withOpacity(0.4),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              "${slState.tracks.length}/20",
                                              style: const TextStyle(
                                                color: Color(0xFFFFD600),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppDimensions.spacingSm),
                                    _buildTrackCarousel(
                                      context,
                                      slState.tracks,
                                      source: "Vos Sonoritiz Superlikes !",
                                    ),
                                    const SizedBox(height: AppDimensions.spacingXl),
                                  ],
                                );
                              },
                            ),

                            // 6. Ambiances du Quotidien (Soirée & Fiesta, Nocturne, Sport, Détente, Focus, Trajet)
                            _buildDailyAmbiancesSection(context, state),

                            // 3. Top 50 Mondial Deezer (Avec Badges Podium #1, #2, #3...)
                            if (state.trendingTracks.isNotEmpty) ...[
                              SonoritizSectionHeader(
                                title: "Top 50 • Classement Mondial",
                                onSeeAll: () => context.push('/trends'),
                              ),
                              const SizedBox(height: AppDimensions.spacingSm),
                              _buildTrackCarousel(
                                context,
                                state.trendingTracks,
                                source: "Top 50 Mondial",
                                showRanks: true,
                              ),
                              const SizedBox(height: AppDimensions.spacingXl),
                            ],

                            // 3.1 Top Cameroun • Hits du 237
                            if (state.cameroonTracks.isNotEmpty) ...[
                              const SonoritizSectionHeader(
                                title: "Top Cameroun • Hits du 237",
                              ),
                              const SizedBox(height: AppDimensions.spacingSm),
                              _buildTrackCarousel(
                                context,
                                state.cameroonTracks,
                                source: "Top Cameroun 237",
                                showRanks: true,
                              ),
                              const SizedBox(height: AppDimensions.spacingXl),
                            ],

                            // 3.2 Top 20 USA • Billboard & Hot Hits
                            if (state.topUsaTracks.isNotEmpty) ...[
                              const SonoritizSectionHeader(
                                title: "Top 20 USA • Billboard & Hot Hits",
                              ),
                              const SizedBox(height: AppDimensions.spacingSm),
                              _buildTrackCarousel(
                                context,
                                state.topUsaTracks,
                                source: "Top 20 USA",
                                showRanks: true,
                              ),
                              const SizedBox(height: AppDimensions.spacingXl),
                            ],

                            // 3.3 100% Afrobeats Uniquement
                            if (state.afrobeatsTracks.isNotEmpty) ...[
                              const SonoritizSectionHeader(
                                title: "100% Afrobeats Uniquement",
                              ),
                              const SizedBox(height: AppDimensions.spacingSm),
                              _buildTrackCarousel(
                                context,
                                state.afrobeatsTracks,
                                source: "100% Afrobeats",
                                showRanks: true,
                              ),
                              const SizedBox(height: AppDimensions.spacingXl),
                            ],

                            // 3.4 Les Tops par Continent (Afrique, Europe, Amérique Latine, Asie)
                            _buildContinentalHub(context, state),

                            // 4. Playlists Éditoriales Officielles Deezer
                            if (state.editorialPlaylists.isNotEmpty) ...[
                              const SonoritizSectionHeader(
                                title: "Playlists Incontournables",
                              ),
                              const SizedBox(height: AppDimensions.spacingSm),
                              _buildEditorialPlaylistsCarousel(context, state.editorialPlaylists),
                              const SizedBox(height: AppDimensions.spacingXl),
                            ],

                              // 6. Mix Quotidiens (Daily Mix)
                              if (state.dailyMixes.isNotEmpty) ...[
                                ...state.dailyMixes.entries.map((entry) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SonoritizSectionHeader(title: entry.key),
                                      const SizedBox(height: AppDimensions.spacingSm),
                                      _buildTrackCarousel(
                                        context,
                                        entry.value,
                                        source: entry.key,
                                      ),
                                      const SizedBox(height: AppDimensions.spacingXl),
                                    ],
                                  );
                                }).toList(),
                              ],

                              // 7. Parce que vous écoutez X (Recommandations Deezer Related)
                              if (state.similarToArtistName != null && state.similarToArtistTracks.isNotEmpty) ...[
                                SonoritizSectionHeader(title: "Parce que vous écoutez ${state.similarToArtistName}"),
                                const SizedBox(height: AppDimensions.spacingSm),
                                _buildTrackCarousel(
                                  context,
                                  state.similarToArtistTracks,
                                  source: "Parce que vous écoutez ${state.similarToArtistName}",
                                ),
                                const SizedBox(height: AppDimensions.spacingXl),
                              ],

                              // 8. Top Artistes du moment (Deezer Chart Artists)
                              if (state.topArtists.isNotEmpty) ...[
                                const SonoritizSectionHeader(title: "Top Artistes du moment"),
                                const SizedBox(height: AppDimensions.spacingSm),
                                _buildTopArtistsCarousel(context, state.topArtists),
                                const SizedBox(height: AppDimensions.spacingXl),
                              ],

                              // 9. Vos Playlists
                              if (state.userPlaylists.isNotEmpty) ...[
                                SonoritizSectionHeader(
                                  title: "Vos Playlists",
                                  onSeeAll: () => context.push('/playlists'),
                                ),
                                const SizedBox(height: AppDimensions.spacingSm),
                                _buildPlaylistCarousel(context, state.userPlaylists),
                                const SizedBox(height: AppDimensions.spacingXl),
                              ],

                              // 10. Vos Favoris
                              if (state.userFavorites.isNotEmpty) ...[
                                SonoritizSectionHeader(
                                  title: "Vos Favoris",
                                  onSeeAll: () => context.push('/favorites'),
                                ),
                                const SizedBox(height: AppDimensions.spacingSm),
                                _buildTrackCarousel(
                                  context,
                                  state.userFavorites,
                                  source: "Vos Favoris",
                                ),
                                const SizedBox(height: AppDimensions.spacingXl),
                              ],

                              // 11. Vos artistes préférés
                              SonoritizSectionHeader(
                                title: "Vos artistes préférés",
                                onSeeAll: () => context.push('/select-artists', extra: context.read<HomeCubit>()),
                              ),
                              const SizedBox(height: AppDimensions.spacingSm),
                              _buildFavoriteArtistsCarousel(context, state.favoriteArtists),
                              const SizedBox(height: AppDimensions.spacingXl),

                              // 12. Quiz Musical
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
                                child: _buildQuizBanner(context),
                              ),
                              const SizedBox(height: AppDimensions.spacingXl),

                              // 13. Podcasts & Livres Audio
                              if (state.podcastTracks.isNotEmpty) ...[
                                SonoritizSectionHeader(
                                  title: "Podcasts & Livres Audio",
                                  onSeeAll: () => context.push('/podcasts'),
                                ),
                                const SizedBox(height: AppDimensions.spacingSm),
                                _buildTrackCarousel(
                                  context,
                                  state.podcastTracks,
                                  source: "Podcasts",
                                ),
                              ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildPremiumAppBar(BuildContext context, HomeLoaded state) {
    final storage = context.read<HomeCubit>().storageService;
    final username = storage.username.isNotEmpty ? storage.username : "User";
    final profileImagePath = storage.getProfileImagePath();
    final lyricSnippet = _getRandomLyricSnippet(
      state.userFavorites,
      fallbackTracks: [...state.recentlyPlayed, ...state.trendingTracks],
    );
    final colorScheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      backgroundColor: colorScheme.surface.withOpacity(0.92),
      floating: true,
      pinned: true,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF141418),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.9,
                ),
              ),
              child: Image.asset(
                'assets/images/logo_transparent.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SonoritizPageTitle(
                  title: "Salut, $username",
                  fontSize: 17,
                ),
                const SizedBox(height: 3),
                Text(
                  lyricSnippet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.mic_rounded, color: colorScheme.onSurface),
          tooltip: "Recherche vocale",
          onPressed: () {
            final homeCubit = context.read<HomeCubit>();
            showDialog(
              context: context,
              builder: (context) => BlocProvider.value(
                value: homeCubit,
                child: const VoiceSearchBottomSheet(),
              ),
            );
          },
        ),
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: Padding(
            padding: const EdgeInsets.only(right: AppDimensions.spacingMd),
            child: Builder(
              builder: (context) {
                final hasLocalAvatar = !kIsWeb &&
                    profileImagePath != null &&
                    SonoritizArtwork.fileExistsCached(profileImagePath);
                return CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage:
                      hasLocalAvatar ? FileImage(File(profileImagePath)) : null,
                  child: !hasLocalAvatar
                      ? Text(
                          username.isNotEmpty
                              ? username[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackCarousel(BuildContext context, List<TrackModel> tracks, {String? source, bool showRanks = false}) {
    final bool isTopMix = showRanks || (source?.toLowerCase().contains('top') ?? false);
    return SizedBox(
      height: 200,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return Padding(
            padding: const EdgeInsets.only(right: AppDimensions.spacingMd),
            child: SonoritizTrackCard(
              imageUrl: track.coverUrl,
              title: track.title,
              subtitle: track.artistName,
              width: 140.0,
              trackId: track.id,
              track: track,
              rank: showRanks ? (index + 1) : null,
              showCenterLogo: isTopMix,
              onTap: () => context.read<PlayerCubit>().playTrack(track, queue: tracks, source: source),
            ),
          );
        },
      ),
    );
  }

  String _sanitizeEditorialName(String? raw, {required String fallback}) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return fallback;
    final cleaned = trimmed
        .replaceAll(RegExp(r'\bdeezer\b', caseSensitive: false), 'Sonoritiz')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    if (cleaned.isEmpty || cleaned.toLowerCase() == 'deezer') {
      return fallback;
    }
    return cleaned;
  }

  void _openEditorialPlaylist(BuildContext context, Map<String, dynamic> playlist) async {
    final playlistId = playlist['id'];
    final playlistTitle = _sanitizeEditorialName(
      playlist['title']?.toString(),
      fallback: 'Playlist Sonoritiz',
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Lancement de $playlistTitle...",
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E1E26),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final repository = context.read<HomeCubit>().catalogRepository;
      final tracks = await repository.getPlaylistTracksDeezer(playlistId, limit: 50);
      if (tracks.isNotEmpty && context.mounted) {
        context.read<PlayerCubit>().playTrack(tracks.first, queue: tracks, source: playlistTitle);
      }
    } catch (_) {}
  }

  Widget _buildEditorialPlaylistsCarousel(BuildContext context, List<Map<String, dynamic>> playlists) {
    return SizedBox(
      height: 215,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          final String title = _sanitizeEditorialName(
            playlist['title']?.toString(),
            fallback: 'Sélection Sonoritiz',
          );
          final String picture = playlist['picture'] ?? '';
          final int nbTracks = playlist['nb_tracks'] ?? 0;
          final String creator = _sanitizeEditorialName(
            playlist['creator']?.toString(),
            fallback: 'Sonoritiz',
          );

          return Padding(
            padding: const EdgeInsets.only(right: AppDimensions.spacingMd),
            child: Semantics(
              button: true,
              label: "Voir $title",
              child: GestureDetector(
                onTap: () {
                  context.push('/album', extra: {
                    'id': playlist['id'],
                    'title': title,
                    'cover': picture,
                    'cover_xl': picture,
                    'artistName': creator,
                    'type': 'playlist',
                    'is_playlist': true,
                  });
                },
                onLongPress: () => CollectionContextMenu.showForAlbum(
                  context,
                  albumId: (playlist['id'] ?? '').toString(),
                  title: title,
                  artistName: creator,
                  coverUrl: picture,
                  isEditorialPlaylist: true,
                ),
                child: SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          SonoritizArtwork(
                            imageUrl: picture,
                            width: 150,
                            height: 150,
                            borderRadius: AppDimensions.radiusMd,
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Opacity(
                                    opacity: 0.88,
                                    child: Image.asset(
                                      'assets/images/logo_transparent.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => _openEditorialPlaylist(context, playlist),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white24, width: 0.6),
                              ),
                              child: const Text(
                                "Éditorial",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$nbTracks titres • $creator",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- 1b. SONS À VENIR & SORTIES DE LA SEMAINE ---
  Widget _buildNewReleaseTracksSection(BuildContext context, HomeLoaded state) {
    final tracks = state.newReleases.take(20).toList();
    if (tracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SonoritizSectionHeader(
          title: "Sons à venir & Sorties",
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        _buildTrackCarousel(
          context,
          tracks,
          source: "Sons à venir & Sorties",
        ),
      ],
    );
  }

  // --- 2. ÉCOUTÉ RÉCEMMENT ---
  Widget _buildRecentlyPlayedSection(BuildContext context, HomeLoaded state) {
    final recentTracks = state.recentlyPlayed
        .where((t) => !t.isPodcastOrBook)
        .take(15)
        .toList();
    if (recentTracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SonoritizSectionHeader(
          title: "Écouté récemment",
          onSeeAll: () => context.push('/history'),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        _buildTrackCarousel(
          context,
          recentTracks,
          source: "Écouté récemment",
        ),
      ],
    );
  }

  String _formatPodcastRemainingLabel(int resumeSec, int totalSec) {
    if (resumeSec > 5 && totalSec > resumeSec) {
      final remMin = math.max(1, (totalSec - resumeSec) ~/ 60);
      if (remMin >= 60) {
        final h = remMin ~/ 60;
        final m = remMin % 60;
        return "Reprendre • ${h}h ${m.toString().padLeft(2, '0')}m rest.";
      }
      return "Reprendre • $remMin min rest.";
    }
    if (resumeSec > 5) {
      final playedMin = math.max(1, resumeSec ~/ 60);
      return "Reprendre à $playedMin min";
    }
    if (totalSec > 0) {
      final totalMin = math.max(1, totalSec ~/ 60);
      if (totalMin >= 60) {
        final h = totalMin ~/ 60;
        final m = totalMin % 60;
        return "${h}h ${m.toString().padLeft(2, '0')}m";
      }
      return "$totalMin min";
    }
    return "Podcast";
  }

  // --- 2b. PODCASTS ÉCOUTÉS RÉCEMMENT (GROS CADRES GLASSMORPHISM + JAUGE DE REPRISE) ---
  Widget _buildRecentPodcastsGlassSection(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: StorageService.recentPodcastsNotifier,
      builder: (context, rawPodcasts, _) {
        final podcasts = rawPodcasts
            .map((m) => TrackModel.fromJson(m))
            .where((t) => t.id.trim().isNotEmpty && t.title.trim().isNotEmpty)
            .toList();
        if (podcasts.isEmpty) return const SizedBox.shrink();

        final storage = StorageService();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SonoritizSectionHeader(
              title: "Podcasts écoutés récemment",
              onSeeAll: () => context.push('/podcasts'),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            SizedBox(
              height: 288,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                ),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: podcasts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final ep = podcasts[index];
                  final int resumeSec = storage.getPodcastResumeSeconds(ep.id);
                  final double progressRatio = (ep.durationSeconds > 0 &&
                          resumeSec > 0)
                      ? (resumeSec / ep.durationSeconds).clamp(0.03, 1.0)
                      : 0.0;
                  final String statusLabel = _formatPodcastRemainingLabel(
                    resumeSec,
                    ep.durationSeconds,
                  );

                  return GestureDetector(
                    onLongPress: () => TrackContextMenu.show(context, ep),
                    onTap: () {
                      final cubit = context.read<PlayerCubit>();
                      if (resumeSec > 5) {
                        cubit.syncExternalMediaTrack(
                          ep,
                          position: Duration(seconds: resumeSec),
                          resumeAudioPlayback: true,
                          source: ep.genre.isNotEmpty
                              ? ep.genre
                              : "Podcasts écoutés récemment",
                        );
                      } else {
                        cubit.playTrack(
                          ep,
                          queue: podcasts,
                          source: ep.genre.isNotEmpty
                              ? ep.genre
                              : "Podcasts écoutés récemment",
                        );
                      }
                    },
                    child: RepaintBoundary(
                      child: Container(
                        width: 226,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF22222C).withValues(alpha: 0.92),
                              const Color(0xFF15151C).withValues(alpha: 0.94),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.34),
                              blurRadius: 14,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    SonoritizArtwork(
                                      imageUrl: ep.coverUrl,
                                      width: double.infinity,
                                      height: double.infinity,
                                      borderRadius: 16,
                                      fit: BoxFit.cover,
                                      cacheMaxDimension: 380,
                                    ),
                                    Positioned(
                                      right: 8,
                                      bottom: progressRatio > 0 ? 12 : 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          context.push(
                                            '/podcast_player',
                                            extra: <String, dynamic>{
                                              'track': ep,
                                              'initialVideoMode': true,
                                              'initialPositionSeconds':
                                                  resumeSec,
                                            },
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.72),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.22),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.videocam_rounded,
                                                color: AppColors.primary,
                                                size: 14,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                "Vidéo",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (progressRatio > 0)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          height: 4,
                                          color: Colors.black
                                              .withValues(alpha: 0.55),
                                          alignment: Alignment.centerLeft,
                                          child: FractionallySizedBox(
                                            widthFactor: progressRatio,
                                            child: Container(
                                              height: 4,
                                              decoration: const BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.horizontal(
                                                  right: Radius.circular(3),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 11),
                            Text(
                              ep.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ep.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.66),
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  resumeSec > 5
                                      ? Icons.play_circle_fill_rounded
                                      : Icons.podcasts_rounded,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    statusLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: resumeSec > 5
                                          ? AppColors.primary
                                          : Colors.white
                                              .withValues(alpha: 0.52),
                                      fontSize: 11.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),
          ],
        );
      },
    );
  }

  // --- 2c. RECOMMANDATION SONORITIZ CONNECT (SONS PROPOSÉS PAR LES INVITÉS) ---
  Widget _buildConnectRecommendationsSection(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: StorageService.connectRecommendationsNotifier,
      builder: (context, rawRecs, _) {
        // Règle stricte : si les invités n'ont proposé aucun son durant les sessions Connect, ne rien ajouter !
        if (rawRecs.isEmpty) return const SizedBox.shrink();

        final tracks = rawRecs
            .map((m) => TrackModel.fromJson(m))
            .where((t) =>
                t.id.trim().isNotEmpty &&
                t.title.trim().isNotEmpty &&
                !t.isPodcastOrBook)
            .toList();
        if (tracks.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SonoritizSectionHeader(
              title: "Recommandation Sonoritiz Connect",
              onSeeAll: () => context.go('/connect'),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            SizedBox(
              height: 200,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                ),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return Padding(
                    padding:
                        const EdgeInsets.only(right: AppDimensions.spacingMd),
                    child: SonoritizTrackCard(
                      imageUrl: track.coverUrl,
                      title: track.title,
                      subtitle: track.artistName,
                      width: 140.0,
                      trackId: track.id,
                      track: track,
                      showConnectCenterLogo: true,
                      onTap: () => context.read<PlayerCubit>().playTrack(
                            track,
                            queue: tracks,
                            source: "Recommandation Sonoritiz Connect",
                          ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),
          ],
        );
      },
    );
  }

  Color _parseAccentColor(dynamic raw) {
    if (raw is Color) return raw;
    if (raw is int) return Color(raw);
    return AppColors.primary;
  }

  String _sanitizeWeeklySubtitle(String raw, int trackCount) {
    final lower = raw.toLowerCase();
    if (!lower.contains('7 ')) return raw;
    final cleaned = raw
        .replaceAll(RegExp(r'\s*\(cycle\s*7\s*jours\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*•\s*Renouvelé\s+tous\s+les\s+7\s+jours', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*alignés\s+sur\s+vos\s+7\s+derniers\s+jours', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*tous\s+les\s+7\s+jours', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*7\s*(?:derniers\s*)?jours', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) {
      return '$trackCount titres inspirés de vos écoutes';
    }
    return cleaned;
  }

  void _openWeeklyCollectionScreen(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color fallbackAccent,
    required String heroCover,
    required List<TrackModel> tracks,
  }) {
    if (tracks.isEmpty) return;
    final mosaic = tracks.length >= 3
        ? PlaylistModel(
            id: -1,
            name: title,
            coverUrl: heroCover,
            tracks: tracks.take(4).toList(),
            tracksCount: tracks.length,
          )
        : null;

    context.push(
      '/collection',
      extra: <String, dynamic>{
        'title': title,
        'badgeLabel': 'BASÉ SUR VOS ÉCOUTES',
        'subtitle': subtitle,
        'metadata': '${tracks.length} ${tracks.length > 1 ? "titres" : "titre"}',
        'coverUrl': heroCover,
        'playlistMosaic': mosaic,
        'tracks': tracks,
        'playbackSource': title,
        'fallbackAccentColor': fallbackAccent,
      },
    );
  }

  Widget _buildReleaseRadarSection(BuildContext context, HomeLoaded state) {
    final followed = StorageService().getFollowedArtists();
    final favNames = state.favoriteArtists
        .map((a) => (a['name'] ?? '').trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final artistSet = <String>{
      ...followed.map((e) => e.toLowerCase().trim()),
      ...favNames.map((e) => e.toLowerCase().trim()),
    }..removeWhere((e) => e.isEmpty || e == 'inconnu');

    final List<TrackModel> radarPool = [];
    final Set<String> seenIds = {};
    for (final t in _releaseRadarTracks) {
      if (seenIds.add(t.id)) radarPool.add(t);
    }
    for (final t in [...state.newReleases, ...state.similarToArtistTracks]) {
      final aLower = t.artistName.toLowerCase();
      if (artistSet.any((name) => aLower.contains(name)) && seenIds.add(t.id)) {
        radarPool.add(t);
      }
    }

    if (radarPool.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.45),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.radar_rounded,
                      color: AppColors.primary,
                      size: 13,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'RADAR',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Radar des Sorties',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  context.read<PlayerCubit>().playTrack(
                        radarPool.first,
                        queue: radarPool,
                        source: 'Radar des Sorties',
                      );
                },
                child: const Text(
                  'Tout écouter',
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
        const SizedBox(height: 3),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
          child: Text(
            'Sélection fraîche de vos artistes suivis et favoris',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        _buildTrackCarousel(
          context,
          radarPool.take(18).toList(),
          source: 'Radar des Sorties',
        ),
        const SizedBox(height: AppDimensions.spacingXl),
      ],
    );
  }

  // --- 3. SONS BASÉS SUR VOS ÉCOUTES (DESIGN « VINYL & GLASS DECK ») ---
  Widget _buildWeeklyCuratedPlaylistsSection(BuildContext context, HomeLoaded state) {
    final playlists = state.weeklyCuratedPlaylists;
    if (playlists.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Sons basés sur vos écoutes",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "5 sélections personnalisées selon votre ADN musical",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 196,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final pl = playlists[index];
              final title = (pl['title'] ?? 'Mix').toString();
              final rawTracks = pl['tracks'] as List? ?? [];
              final tracks = rawTracks
                  .map((t) => TrackModel.fromJson(Map<String, dynamic>.from(t as Map)))
                  .toList();
              final subtitle = _sanitizeWeeklySubtitle(
                (pl['subtitle'] ?? '${tracks.length} morceaux').toString(),
                tracks.length,
              );
              final accent = _parseAccentColor(pl['accent']);
              final cover = (pl['cover'] ?? '').toString();
              final covers = (pl['covers'] as List? ?? [])
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final heroCover =
                  cover.isNotEmpty ? cover : (covers.isNotEmpty ? covers.first : '');

              return _WeeklyCuratedCard(
                title: title,
                subtitle: subtitle,
                heroCover: heroCover,
                covers: covers,
                fallbackAccent: accent,
                tracks: tracks,
                onTap: () => _openWeeklyCollectionScreen(
                  context,
                  title: title,
                  subtitle: subtitle,
                  fallbackAccent: accent,
                  heroCover: heroCover,
                  tracks: tracks,
                ),
                onLongPress: () {
                  if (tracks.isEmpty) return;
                  CollectionContextMenu.showForPlaylist(
                    context,
                    playlist: PlaylistModel(
                      id: -1 - index,
                      name: title,
                      coverUrl: heroCover,
                      tracks: tracks,
                      tracksCount: tracks.length,
                    ),
                  );
                },
                onPlayTap: () {
                  if (tracks.isNotEmpty) {
                    context.read<PlayerCubit>().playTrack(
                          tracks.first,
                          queue: tracks,
                          source: title,
                        );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 4. SONORITIZ RANDOM (25 MORCEAUX OPPOSÉS AVEC SLOGAN OFFICIEL) ---
  Widget _buildSonoritizRandomSection(BuildContext context, HomeLoaded state) {
    final randomTracks = state.sonoritizRandomTracks;
    if (randomTracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SonoritizSectionHeader(
          title: "Sonoritiz Random",
          seeAllText: "Tout lire",
          onSeeAll: () {
            context.read<PlayerCubit>().playTrack(
              randomTracks.first,
              queue: randomTracks,
              source: "Sonoritiz Random",
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
          child: Text(
            "Découvertes fraîches sélectionnées en harmonie avec votre univers musical.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        _buildTrackCarousel(
          context,
          randomTracks,
          source: "Sonoritiz Random",
        ),
      ],
    );
  }

  Widget _buildDailyAmbiancesSection(BuildContext context, HomeLoaded state) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ambiances = const [
      {
        'id': 'soiree',
        'title': 'Soirée & Fiesta',
        'icon': Icons.celebration_rounded,
      },
      {
        'id': 'nocturne',
        'title': 'Nocturne',
        'icon': Icons.nightlife_rounded,
      },
      {
        'id': 'sport',
        'title': 'Sport & Boost',
        'icon': Icons.fitness_center_rounded,
      },
      {
        'id': 'detente',
        'title': 'Détente & Chill',
        'icon': Icons.spa_rounded,
      },
      {
        'id': 'focus',
        'title': 'Focus & Travail',
        'icon': Icons.headphones_rounded,
      },
      {
        'id': 'trajet',
        'title': 'Sur la Route',
        'icon': Icons.directions_car_rounded,
      },
    ];

    final activeAmbiance = ambiances.firstWhere(
      (a) => a['id'] == state.selectedMood,
      orElse: () => ambiances[3],
    );
    final activeTitle = activeAmbiance['title'] as String;
    final displayTracks = state.moodTracks.isNotEmpty
        ? state.moodTracks
        : state.contextualTracks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SonoritizSectionHeader(
          title: "Ambiances du Quotidien",
          seeAllText: "Lancer",
          onSeeAll: displayTracks.isNotEmpty
              ? () => context.read<PlayerCubit>().playTrack(
                    displayTracks.first,
                    queue: displayTracks,
                    source: "Ambiance • $activeTitle",
                  )
              : null,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        SizedBox(
          height: 46,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: 4,
            ),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: ambiances.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = ambiances[index];
              final id = item['id'] as String;
              final title = item['title'] as String;
              final icon = item['icon'] as IconData;
              final isSelected = state.selectedMood == id;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.read<HomeCubit>().selectMood(id),
                  borderRadius: BorderRadius.circular(30),
                  splashColor: colorScheme.primary.withValues(alpha: 0.2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : Colors.white70,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          title,
                          style: isSelected
                              ? textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimary,
                                )
                              : textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white70,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        if (state.isMoodLoading)
          const SizedBox(
            height: 200,
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          )
        else if (displayTracks.isNotEmpty)
          _buildTrackCarousel(
            context,
            displayTracks,
            source: "Ambiance • $activeTitle",
          ),
        const SizedBox(height: AppDimensions.spacingXl),
      ],
    );
  }

  Widget _buildContinentalHub(BuildContext context, HomeLoaded state) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tracks = state.continentalCharts[state.selectedContinent] ?? [];

    final List<Map<String, String>> continents = const [
      {'key': 'africa', 'label': 'Afrique'},
      {'key': 'europe', 'label': 'Europe'},
      {'key': 'latam', 'label': 'Amérique Latine'},
      {'key': 'asia', 'label': 'Asie & Océanie'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SonoritizSectionHeader(title: "Les Tops par Continent"),
        const SizedBox(height: AppDimensions.spacingSm),
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: continents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final c = continents[index];
              final key = c['key']!;
              final label = c['label']!;
              final isSelected = state.selectedContinent == key;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.read<HomeCubit>().selectContinent(key),
                  borderRadius: BorderRadius.circular(30),
                  splashColor: colorScheme.primary.withOpacity(0.2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: isSelected ? colorScheme.primary : Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        "$label (Top 30)",
                        style: isSelected
                            ? textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimary,
                              )
                            : textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        if (state.isContinentLoading) ...[
          const SizedBox(
            height: 180,
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
              ),
            ),
          ),
        ] else if (tracks.isNotEmpty) ...[
          _buildTrackCarousel(
            context,
            tracks,
            source: "Top 30 ${continents.firstWhere((c) => c['key'] == state.selectedContinent, orElse: () => {'label': 'Continent'})['label']}",
            showRanks: true,
          ),
        ] else ...[
          const SizedBox.shrink(),
        ],
        const SizedBox(height: AppDimensions.spacingXl),
      ],
    );
  }

  Widget _buildPlaylistCarousel(BuildContext context, List<dynamic> playlists) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return Padding(
            padding: const EdgeInsets.only(right: AppDimensions.spacingMd),
            child: Semantics(
              button: true,
              label: "Ouvrir la playlist ${playlist.name}",
              child: GestureDetector(
                onTap: () {
                  context.push('/playlist', extra: playlist);
                },
                onLongPress: () {
                  if (playlist is PlaylistModel) {
                    CollectionContextMenu.showForPlaylist(
                      context,
                      playlist: playlist,
                    );
                  }
                },
                child: SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlaylistCoverMosaic(
                        playlist: playlist,
                        size: 140,
                        borderRadius: AppDimensions.radiusMd,
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        "Playlist",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopArtistsCarousel(BuildContext context, List<Map<String, String>> artists) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
        scrollDirection: Axis.horizontal,
        itemCount: artists.length,
        itemBuilder: (context, index) {
          final artist = artists[index];
          final name = artist['name'] ?? 'Inconnu';
          final imageUrl = artist['imageUrl'] ?? '';
          return Padding(
            padding: const EdgeInsets.only(right: AppDimensions.spacingMd),
            child: SonoritizArtistCircleCard(
              imageUrl: imageUrl,
              name: name,
              onTap: () => context.push('/artist', extra: {'name': name}),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFavoriteArtistsCarousel(BuildContext context, List<Map<String, String>> artists) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 180,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
        scrollDirection: Axis.horizontal,
        children: [
          // Artist Avatars first
          ...artists.map((artist) {
            return Padding(
              padding: const EdgeInsets.only(right: AppDimensions.spacingMd),
              child: SonoritizArtistCircleCard(
                imageUrl: artist['imageUrl'] ?? "",
                name: artist['name'] ?? "Inconnu",
                onTap: () => context.push('/artist', extra: artist),
              ),
            );
          }),
          // Add Button after existing artists
          Padding(
            padding: const EdgeInsets.only(right: AppDimensions.spacingMd),
            child: Semantics(
              button: true,
              label: "Ajouter un artiste préféré",
              child: GestureDetector(
                onTap: () => context.push('/select-artists', extra: context.read<HomeCubit>()),
                child: SizedBox(
                  width: 140,
                  child: Column(
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.35),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(Icons.add_rounded, color: colorScheme.primary, size: AppDimensions.iconXl),
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      Text(
                        "Ajouter",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: "Lancer le quiz musical",
      child: GestureDetector(
        onTap: () => context.push('/quiz'),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(Icons.music_note_rounded, size: 100, color: colorScheme.onPrimary.withOpacity(0.2)),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingLg),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingSm),
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.videogame_asset_rounded, color: colorScheme.onPrimary, size: 28),
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Quiz Musical",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.onPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Teste tes connaissances !",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onPrimary.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: colorScheme.onPrimary, size: AppDimensions.iconSm),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingXxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 64),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            ElevatedButton(
              onPressed: () => context.read<HomeCubit>().loadHomeData(),
              child: const Text("Réessayer"),
            )
          ],
        ),
      ),
    );
  }
}

class _WeeklyCuratedCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String heroCover;
  final List<String> covers;
  final Color fallbackAccent;
  final List<TrackModel> tracks;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onPlayTap;

  const _WeeklyCuratedCard({
    required this.title,
    required this.subtitle,
    required this.heroCover,
    required this.covers,
    required this.fallbackAccent,
    required this.tracks,
    required this.onTap,
    this.onLongPress,
    required this.onPlayTap,
  });

  @override
  State<_WeeklyCuratedCard> createState() => _WeeklyCuratedCardState();
}

class _WeeklyCuratedCardState extends State<_WeeklyCuratedCard> {
  ImmersivePalette? _palette;
  String _loadedUrl = '';

  @override
  void initState() {
    super.initState();
    _resolvePalette();
  }

  @override
  void didUpdateWidget(covariant _WeeklyCuratedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heroCover != widget.heroCover) {
      _resolvePalette();
    }
  }

  void _resolvePalette() {
    final url = widget.heroCover.trim();
    _loadedUrl = url;
    if (url.isEmpty) {
      _palette = null;
      return;
    }
    final cached = PaletteService.getCached(url);
    if (cached != null) {
      _palette = cached;
      return;
    }
    PaletteService.getPalette(url).then((palette) {
      if (!mounted || _loadedUrl != url) return;
      setState(() => _palette = palette);
    });
  }

  Widget _coverTile(String url, Color accent) {
    if (url.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.55),
              const Color(0xFF1A1A22),
            ],
          ),
        ),
        child: const Center(
          child: Icon(Icons.music_note_rounded, color: Colors.white54, size: 28),
        ),
      );
    }
    if (kIsWeb) {
      return SonoritizArtwork(
        imageUrl: url,
        width: double.infinity,
        height: double.infinity,
        borderRadius: 0,
        fit: BoxFit.cover,
        cacheMaxDimension: 268,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFF222228),
        child: const Icon(Icons.music_note_rounded, color: Colors.white38),
      ),
    );
  }

  String _buildArtistsPreview() {
    final seen = <String>{};
    final names = <String>[];
    for (final t in widget.tracks) {
      final primary = t.artistName
          .split(RegExp(r'\s*(?:,|feat\.?|ft\.?|&)\s*', caseSensitive: false))
          .first
          .trim();
      if (primary.isNotEmpty &&
          primary.toLowerCase() != 'inconnu' &&
          seen.add(primary.toLowerCase())) {
        names.add(primary);
        if (names.length >= 3) break;
      }
    }
    if (names.isEmpty) return widget.subtitle;
    return 'Avec ${names.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final Color rawDominant = _palette?.dominantColor ?? widget.fallbackAccent;
    final hsl = HSLColor.fromColor(rawDominant);
    final Color accentColor = hsl.saturation < 0.08
        ? AppColors.primary
        : hsl
            .withSaturation(hsl.saturation.clamp(0.52, 0.94))
            .withLightness(hsl.lightness.clamp(0.46, 0.64))
            .toColor();
    final Color topSurface =
        Color.lerp(rawDominant, const Color(0xFF14151C), 0.56) ??
            const Color(0xFF1B1C24);
    final Color bottomSurface =
        Color.lerp(rawDominant, const Color(0xFF0A0A0E), 0.82) ??
            const Color(0xFF101116);
    final Color playIconColor =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.light
            ? Colors.black
            : Colors.white;

    final String cover0 = widget.heroCover.isNotEmpty
        ? widget.heroCover
        : (widget.covers.isNotEmpty ? widget.covers.first : '');
    final String cover1 =
        widget.covers.length > 1 ? widget.covers[1] : cover0;
    final String cover2 =
        widget.covers.length > 2 ? widget.covers[2] : cover1;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        width: 306,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topSurface, bottomSurface],
          ),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.42),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            // Colonne gauche : Empilement 3D en cascade des 3 pochettes + Vrai logo d'origine
            SizedBox(
              width: 120,
              height: 162,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  // 3e pochette (arrière-plan décalé à droite)
                  Positioned(
                    left: 34,
                    top: 24,
                    child: Transform.rotate(
                      angle: 0.10,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Opacity(
                          opacity: 0.55,
                          child: _coverTile(cover2, accentColor),
                        ),
                      ),
                    ),
                  ),
                  // 2e pochette (plan intermédiaire)
                  Positioned(
                    left: 18,
                    top: 16,
                    child: Transform.rotate(
                      angle: 0.045,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Opacity(
                          opacity: 0.80,
                          child: _coverTile(cover1, accentColor),
                        ),
                      ),
                    ),
                  ),
                  // 1re pochette Hero au premier plan
                  Positioned(
                    left: 0,
                    top: 10,
                    child: Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.34),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.48),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _coverTile(cover0, accentColor),
                    ),
                  ),
                  // Médaillon discret du vrai logo d'origine (orange & blanc) en bas à gauche
                  Positioned(
                    left: 6,
                    bottom: 24,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.32),
                          width: 0.9,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Colonne droite : Métadonnées éditoriales + Bouton Play capsule + Options •••
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'MIX • ${widget.tracks.length} TITRES',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 9.8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          height: 1.16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _buildArtistsPreview(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onPlayTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                color: playIconColor,
                                size: 17,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Écouter',
                                style: TextStyle(
                                  color: playIconColor,
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (widget.onLongPress != null)
                        GestureDetector(
                          onTap: widget.onLongPress,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.white.withValues(alpha: 0.75),
                              size: 17,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
