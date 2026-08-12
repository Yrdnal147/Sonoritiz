import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:math' show Random;
import '../../library/presentation/playlist_detail_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/track_context_menu.dart';
import '../../../core/widgets/artist_name_display.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../library/data/repositories/library_repository.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../data/repositories/catalog_repository.dart';
import 'cubit/home_cubit.dart';
import 'cubit/home_state.dart';
import 'widgets/home_skeleton.dart';
import '../../player/data/models/track_model.dart';
import '../../../core/utils/responsive_utils.dart';
import 'dart:math' as math;

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

class _HomeScreenBody extends StatelessWidget {
  const _HomeScreenBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () => context.read<HomeCubit>().loadHomeData(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildPremiumAppBar(context),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 120.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Tendances
                          if (state.recentTrends.isNotEmpty) ...[
                            _buildSectionHeader("Tendances", onSeeAll: () => context.push('/trends'))
                                .animate().fadeIn().slideX(begin: -0.1),
                            const SizedBox(height: 12),
                            _buildSmallTrackCarousel(context, state.recentTrends)
                                .animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
                            const SizedBox(height: 32),
                          ],

                          // 2. Recommandations
                          if (state.recommendations.isNotEmpty) ...[
                            _buildSectionHeader("Recommandé pour vous", onSeeAll: null)
                                .animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                            const SizedBox(height: 12),
                            _buildTrackCarousel(context, state.recommendations)
                                .animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                            const SizedBox(height: 32),
                          ],

                          // 3. Vos Playlists
                          if (state.userPlaylists.isNotEmpty) ...[
                            _buildSectionHeader("Vos Playlists", onSeeAll: () => context.go('/library'))
                                .animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
                            const SizedBox(height: 12),
                            _buildPlaylistCarousel(context, state.userPlaylists)
                                .animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
                            const SizedBox(height: 32),
                          ],

                          // 4. Vos Favoris
                          if (state.userFavorites.isNotEmpty) ...[
                            _buildSectionHeader("Vos Favoris", onSeeAll: () => context.go('/library'))
                                .animate().fadeIn(delay: 600.ms).slideX(begin: -0.1),
                            const SizedBox(height: 12),
                            _buildFavoritesCarousel(context, state.userFavorites)
                                .animate().fadeIn(delay: 700.ms).slideY(begin: 0.1),
                            const SizedBox(height: 32),
                          ],

                          // 5. Top Artistes (1-20)
                          if (state.topArtists.isNotEmpty) ...[
                            _buildSectionHeader("Top Artistes du moment", onSeeAll: null)
                                .animate().fadeIn(delay: 800.ms).slideX(begin: -0.1),
                            const SizedBox(height: 12),
                            _buildTopArtistsCarousel(context, state.topArtists)
                                .animate().fadeIn(delay: 900.ms).slideY(begin: 0.1),
                            const SizedBox(height: 32),
                          ],

                          // 6. Vos artistes préférés
                          _buildSectionHeader("Vos artistes préférés", onSeeAll: () => context.push('/select-artists'))
                              .animate().fadeIn(delay: 1000.ms).slideX(begin: -0.1),
                          const SizedBox(height: 12),
                          _buildFavoriteArtistsCarousel(context, state.favoriteArtists)
                              .animate().fadeIn(delay: 1100.ms).slideY(begin: 0.1),
                          const SizedBox(height: 32),

                          // 7. Quiz Musical Banner
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _buildQuizBanner(context)
                                .animate().fadeIn(delay: 1200.ms).slideX(begin: -0.1),
                          ),
                          const SizedBox(height: 32),

                          // 8. Podcasts
                          if (state.podcastTracks.isNotEmpty) ...[
                            _buildSectionHeader("Podcasts Vidéo & Audio", onSeeAll: () => context.push('/podcasts'))
                                .animate().fadeIn(delay: 1300.ms).slideX(begin: -0.1),
                            const SizedBox(height: 12),
                            _buildPodcastCarousel(context, state.podcastTracks)
                                .animate().fadeIn(delay: 1400.ms).slideY(begin: 0.1),
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

  Widget _buildPremiumAppBar(BuildContext context) {
    final storage = context.read<HomeCubit>().storageService;
    final username = storage.username.isNotEmpty ? storage.username : "Fan de musique";
    final profileImagePath = storage.getProfileImagePath();

    final hour = DateTime.now().hour;
    final greeting = (hour < 18) ? "Bonjour" : "Bonsoir";

    return SliverAppBar(
      backgroundColor: AppColors.background,
      expandedHeight: 120.0,
      floating: true,
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => context.go('/profile'),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceLight,
                backgroundImage: profileImagePath != null && File(profileImagePath).existsSync()
                    ? FileImage(File(profileImagePath))
                    : null,
                child: profileImagePath == null || !File(profileImagePath).existsSync()
                    ? Text(username.isNotEmpty ? username[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontSize: 14))
                    : null,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withOpacity(0.15),
                AppColors.background,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                "Voir tout",
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- CAROUSELS ---

  Widget _buildSmallTrackCarousel(BuildContext context, List<TrackModel> tracks) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return GestureDetector(
            onTap: () => context.read<PlayerCubit>().playTrack(track, queue: tracks),
            child: Container(
              width: 120,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: track.coverUrl,
                      width: 120,
                      height: 90,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => _buildPlaceholder(120, 90),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  ArtistNameDisplay(
                    artistName: track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return GestureDetector(
            onTap: () => context.read<PlayerCubit>().playTrack(track, queue: tracks),
            child: Container(
              width: 160,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: track.coverUrl,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => _buildPlaceholder(160, 160),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistCarousel(BuildContext context, List<dynamic> playlists) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlist: playlist),
                ),
              );
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.queue_music, color: AppColors.primary, size: 48),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFavoritesCarousel(BuildContext context, List<TrackModel> tracks) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return GestureDetector(
            onTap: () => context.read<PlayerCubit>().playTrack(track, queue: tracks),
            child: Container(
              width: 150,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: track.coverUrl.startsWith("file://")
                        ? Image.file(
                            File(track.coverUrl.replaceFirst("file://", "")),
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(150, 150),
                          )
                        : CachedNetworkImage(
                            imageUrl: track.coverUrl,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _buildPlaceholder(150, 150),
                          ),
                  ),
                  const SizedBox(height: 8),
                  ArtistNameDisplay(
                    artistName: track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopArtistsCarousel(BuildContext context, List<String> artists) {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: artists.length,
        itemBuilder: (context, index) {
          final artist = artists[index];
          final rank = index + 1;
          return GestureDetector(
            onTap: () => context.push('/artist-playlist', extra: artist),
            child: Container(
              width: 140,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: 140,
                    height: 190,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [AppColors.primary.withOpacity(0.8), AppColors.surface],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.person, size: 64, color: Colors.white30),
                    ),
                  ),
                  Positioned(
                    top: -10,
                    left: -10,
                    child: Text(
                      "#$rank",
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.2),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  Container(
                    width: 140,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Text(
                      artist,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFavoriteArtistsCarousel(BuildContext context, List<Map<String, String>> artists) {
    return SizedBox(
      height: 160, // Augmenté pour les cercles plus grands
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          // Add Button
          GestureDetector(
            onTap: () => context.push('/select-artists'),
            child: Container(
              width: 120, // Augmenté pour correspondre aux cercles
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60, // 50% plus grand
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: const Icon(Icons.add, color: AppColors.primary, size: 40),
                  ),
                  const SizedBox(height: 12),
                  const Text("Ajouter", style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          // Artist Avatars
          ...artists.asMap().entries.map((entry) {
            final index = entry.key;
            final artist = entry.value;
            final isFirst = index == 0;
            return GestureDetector(
              onTap: () => context.push('/artist', extra: artist),
              child: Container(
                width: 120,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isFirst ? Border.all(color: AppColors.primary, width: 2.0) : null,
                      ),
                      child: ClipOval(
                        child: artist['imageUrl']!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: artist['imageUrl']!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  width: 120, height: 120, color: AppColors.surfaceLight,
                                  child: Center(
                                    child: Text(
                                      artist['name']![0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: 120, height: 120, color: AppColors.surfaceLight,
                                child: Center(
                                  child: Text(
                                    artist['name']![0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      artist['name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuizBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/quiz');
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(Icons.music_note, size: 100, color: Colors.white.withOpacity(0.2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videogame_asset, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Quiz Musical",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Teste tes connaissances !",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodcastCarousel(BuildContext context, List<TrackModel> tracks) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return GestureDetector(
            onTap: () {
              // Aller à la vue artiste
              // Pour simplifier on passe juste le nom
            },
            child: Container(
              width: 100, // Plus petit pour des ronds
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: track.coverUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => ClipOval(child: _buildPlaceholder(100, 100)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceLight,
      child: const Center(
        child: Icon(Icons.music_note, color: AppColors.textSecondary, size: 32),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.read<HomeCubit>().loadHomeData(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text("Réessayer"),
            )
          ],
        ),
      ),
    );
  }
}

class _ShimmerLoading extends StatelessWidget {
  const _ShimmerLoading({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 80, height: 14, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 140, height: 24, color: Colors.white),
                  ],
                ),
                Container(width: 36, height: 36, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(width: 120, height: 24, color: Colors.white),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (_, __) => Container(
                width: 120,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Container(width: 120, height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
