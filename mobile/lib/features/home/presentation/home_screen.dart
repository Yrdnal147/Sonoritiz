import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/playlist_cover_mosaic.dart';
import '../../../core/widgets/sonoritiz_section_header.dart';
import '../../../core/widgets/sonoritiz_track_card.dart';
import '../../../core/widgets/sonoritiz_artist_circle_card.dart';
import '../../../core/widgets/sonoritiz_artwork.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';

import '../../library/data/repositories/library_repository.dart';
import '../../library/presentation/playlist_detail_screen.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../search/presentation/widgets/voice_search_bottom_sheet.dart';

import '../data/repositories/catalog_repository.dart';
import 'cubit/home_cubit.dart';
import 'cubit/home_state.dart';
import 'widgets/home_skeleton.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeCubit>(
      create: (context) {
        final storage = StorageService();
        final apiClient = ApiClient(storageService: storage);
        return HomeCubit(
          catalogRepository: CatalogRepository(apiClient: apiClient),
          libraryRepository: LibraryRepository(apiClient: apiClient),
          storageService: storage,
        )..loadHomeData();
      },
      child: const _HomeScreenBody(),
    );
  }
}

class _HomeScreenBody extends StatefulWidget {
  const _HomeScreenBody({Key? key}) : super(key: key);

  @override
  State<_HomeScreenBody> createState() => _HomeScreenBodyState();
}

class _HomeScreenBodyState extends State<_HomeScreenBody> {
  late int _lyricSeed;

  @override
  void initState() {
    super.initState();
    _lyricSeed = DateTime.now().millisecondsSinceEpoch;
  }

  String _getRandomLyricSnippet(List<TrackModel> favorites) {
    if (favorites.isEmpty) return "♪ Bienvenue sur Sonoritiz";
    final random = math.Random(_lyricSeed);
    final track = favorites[random.nextInt(favorites.length)];
    final snippets = [
      "\"${track.title}\" — ${track.artistName}",
      "♪ ${track.title}",
      "${track.artistName} — ${track.title}",
    ];
    return snippets[random.nextInt(snippets.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return const HomeSkeleton();
          }

          if (state is HomeError) {
            return _buildErrorState(context, state.message);
          }

          if (state is HomeLoaded) {
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
                          if (state.recentTrends.isNotEmpty) ...[
                            SonoritizSectionHeader(
                              title: "Tendances",
                              onSeeAll: () => context.push('/trends'),
                            ),
                            const SizedBox(height: AppDimensions.spacingSm),
                            _buildSmallTrackGrid(context, state.recentTrends),
                            const SizedBox(height: AppDimensions.spacingXl),
                          ],

                          if (state.recommendations.isNotEmpty) ...[
                            const SonoritizSectionHeader(title: "Recommandé pour vous"),
                            const SizedBox(height: AppDimensions.spacingSm),
                            _buildTrackCarousel(context, state.recommendations),
                            const SizedBox(height: AppDimensions.spacingXl),
                          ],

                          if (state.userPlaylists.isNotEmpty) ...[
                            SonoritizSectionHeader(
                              title: "Vos Playlists",
                              onSeeAll: () => context.go('/library'),
                            ),
                            const SizedBox(height: AppDimensions.spacingSm),
                            _buildPlaylistCarousel(context, state.userPlaylists),
                            const SizedBox(height: AppDimensions.spacingXl),
                          ],

                          if (state.userFavorites.isNotEmpty) ...[
                            SonoritizSectionHeader(
                              title: "Vos Favoris",
                              onSeeAll: () => context.go('/library'),
                            ),
                            const SizedBox(height: AppDimensions.spacingSm),
                            _buildTrackCarousel(context, state.userFavorites),
                            const SizedBox(height: AppDimensions.spacingXl),
                          ],

                          if (state.topArtists.isNotEmpty) ...[
                            const SonoritizSectionHeader(title: "Top Artistes du moment"),
                            const SizedBox(height: AppDimensions.spacingSm),
                            _buildTopArtistsCarousel(context, state.topArtists),
                            const SizedBox(height: AppDimensions.spacingXl),
                          ],

                          SonoritizSectionHeader(
                            title: "Vos artistes préférés",
                            onSeeAll: () => context.push('/select-artists'),
                          ),
                          const SizedBox(height: AppDimensions.spacingSm),
                          _buildFavoriteArtistsCarousel(context, state.favoriteArtists),
                          const SizedBox(height: AppDimensions.spacingXl),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
                            child: _buildQuizBanner(context),
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),

                          if (state.podcastTracks.isNotEmpty) ...[
                            SonoritizSectionHeader(
                              title: "Podcasts Vidéo & Audio",
                              onSeeAll: () => context.push('/podcasts'),
                            ),
                            const SizedBox(height: AppDimensions.spacingSm),
                            _buildTrackCarousel(context, state.podcastTracks),
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
    );
  }

  Widget _buildPremiumAppBar(BuildContext context, HomeLoaded state) {
    final storage = context.read<HomeCubit>().storageService;
    final username = storage.username.isNotEmpty ? storage.username : "User";
    final profileImagePath = storage.getProfileImagePath();
    final lyricSnippet = _getRandomLyricSnippet(state.userFavorites);
    final colorScheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      backgroundColor: colorScheme.surface,
      floating: true,
      pinned: true,
      elevation: 0,
      title: Text(
        lyricSnippet,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
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
          onTap: () => context.go('/profile'),
          child: Padding(
            padding: const EdgeInsets.only(right: AppDimensions.spacingMd),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: profileImagePath != null && File(profileImagePath).existsSync()
                  ? FileImage(File(profileImagePath))
                  : null,
              child: profileImagePath == null || !File(profileImagePath).existsSync()
                  ? Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 14, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallTrackGrid(BuildContext context, List<TrackModel> tracks) {
    final displayTracks = tracks.take(6).toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3.0,
          crossAxisSpacing: AppDimensions.spacingSm,
          mainAxisSpacing: AppDimensions.spacingSm,
        ),
        itemCount: displayTracks.length,
        itemBuilder: (context, index) {
          final track = displayTracks[index];
          return Semantics(
            button: true,
            label: "Jouer ${track.title}",
            child: GestureDetector(
              onTap: () => context.read<PlayerCubit>().playTrack(track, queue: tracks),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    SonoritizArtwork(
                      imageUrl: track.coverUrl,
                      width: 56,
                      height: 56,
                      borderRadius: 0,
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingXs),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrackCarousel(BuildContext context, List<TrackModel> tracks) {
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
              onTap: () => context.read<PlayerCubit>().playTrack(track, queue: tracks),
            ),
          );
        },
      ),
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(playlist: playlist),
                    ),
                  );
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

  Widget _buildTopArtistsCarousel(BuildContext context, List<String> artists) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
        scrollDirection: Axis.horizontal,
        itemCount: artists.length,
        itemBuilder: (context, index) {
          final artist = artists[index];
          return Padding(
            padding: const EdgeInsets.only(right: AppDimensions.spacingMd),
            child: SonoritizArtistCircleCard(
              imageUrl: "", // Top artists from API don't have images easily available yet in HomeCubit
              name: artist,
              onTap: () => context.push('/artist-playlist', extra: artist),
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
          // Add Button
          Padding(
            padding: const EdgeInsets.only(right: AppDimensions.spacingMd),
            child: Semantics(
              button: true,
              label: "Ajouter un artiste préféré",
              child: GestureDetector(
                onTap: () => context.push('/select-artists'),
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
                        ),
                        child: Icon(Icons.add_rounded, color: colorScheme.onSurfaceVariant, size: AppDimensions.iconXl),
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      Text(
                        "Ajouter",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Artist Avatars
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
