import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../data/repositories/catalog_repository.dart';
import 'cubit/home_cubit.dart';
import 'cubit/home_state.dart';
import '../../player/data/models/track_model.dart';
import '../../../core/utils/responsive_utils.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeCubit>(
      create: (context) {
        final storage = StorageService();
        return HomeCubit(
          repository: CatalogRepository(apiClient: ApiClient(storageService: storage)),
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
            return const SafeArea(child: _ShimmerLoading());
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
                      padding: const EdgeInsets.only(top: 24.0, bottom: 120.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader("Tendances", onSeeAll: () => context.go('/search'))
                              .animate().fadeIn().slideX(begin: -0.1),
                          const SizedBox(height: 16),
                          _buildTrendingCarousel(context, state.trendingTracks)
                              .animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
                          
                          const SizedBox(height: 40),
                          
                          _buildSectionHeader("Nouveautés", onSeeAll: () => context.go('/search'))
                              .animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                          const SizedBox(height: 16),
                          _buildTrackCarousel(context, state.newReleases)
                              .animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                          
                          const SizedBox(height: 40),
                          
                          _buildSectionHeader("Explorer les genres", onSeeAll: () => context.go('/search'))
                              .animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
                          const SizedBox(height: 16),
                          _buildGenreCarousel(context, state.genres)
                              .animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
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
    final hour = DateTime.now().hour;
    final greeting = (hour < 18) ? "Bonjour" : "Bonsoir";

    return SliverAppBar(
      backgroundColor: AppColors.background,
      expandedHeight: 140.0,
      floating: true,
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "Sonoritiz",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withOpacity(0.2),
                AppColors.background,
              ],
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Colors.white, size: 28),
                onPressed: () => context.go('/search'),
              ).animate().fadeIn(delay: 200.ms).scale(),
              GestureDetector(
                onTap: () => context.go('/profile'),
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceLight,
                  child: Icon(Icons.person, color: Colors.white70, size: 20),
                ),
              ).animate().fadeIn(delay: 300.ms).scale(),
              const SizedBox(width: 8),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.primary.withOpacity(0.8))
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.1, duration: 1.seconds),
          const SizedBox(height: 24),
          Text(message, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.read<HomeCubit>().loadHomeData(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 8,
              shadowColor: AppColors.primary.withOpacity(0.5),
            ),
            child: const Text("Rafraîchir", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ).animate().fadeIn().scale(curve: Curves.easeOutBack),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Text("Voir tout", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendingCarousel(BuildContext context, List<TrackModel> tracks) {
    if (tracks.isEmpty) return const SizedBox();
    
    // PageController allows us to show a peek of the previous/next cards
    final PageController pageController = PageController(viewportFraction: 0.85);

    return SizedBox(
      height: 240,
      child: PageView.builder(
        controller: pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: tracks.length > 8 ? 8 : tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return AnimatedBuilder(
            animation: pageController,
            builder: (context, child) {
              double value = 1.0;
              if (pageController.position.haveDimensions) {
                value = pageController.page! - index;
                value = (1 - (value.abs() * 0.2)).clamp(0.8, 1.0);
              }
              return Center(
                child: SizedBox(
                  height: Curves.easeOut.transform(value) * 240,
                  width: Curves.easeOut.transform(value) * 400,
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTap: () => context.read<PlayerCubit>().playTrack(track, queue: tracks),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background Image
                      track.coverUrl.isNotEmpty
                          ? CachedNetworkImage(imageUrl: track.coverUrl, fit: BoxFit.cover)
                          : Container(color: AppColors.surface),
                      
                      // Dark Overlay for text readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                          ),
                        ),
                      ),
                      
                      // Glassmorphism bottom bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: ClipRRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.white.withOpacity(0.1),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.title,
                                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          track.artistName,
                                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const CircleAvatar(
                                    backgroundColor: AppColors.primary,
                                    radius: 20,
                                    child: Icon(Icons.play_arrow_rounded, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
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


  Widget _buildTrackCarousel(BuildContext context, List<TrackModel> tracks) {
    if (tracks.isEmpty) return const SizedBox();

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return GestureDetector(
            onTap: () => context.read<PlayerCubit>().playTrack(track, queue: tracks),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          track.coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: track.coverUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: AppColors.surfaceLight),
                                )
                              : Container(color: AppColors.surface, child: const Icon(Icons.music_note, color: Colors.white38)),
                          // Play overlay effect
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            bottom: 8,
                            right: 8,
                            child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGenreCarousel(BuildContext context, List<Map<String, String>> genres) {
    final gradients = [
      const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF9C27B0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF00BCD4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFF5722)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      const LinearGradient(colors: [Color(0xFF673AB7), Color(0xFF3F51B5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    ];

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          final gradient = gradients[index % gradients.length];

          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: gradient, 
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: gradient.colors.last.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
              ]
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.go('/search'),
                child: Center(
                  child: Text(
                    genre['name'] ?? '',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
          );
        },
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 150, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                itemBuilder: (_, __) => Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 140, height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                      const SizedBox(height: 12),
                      Container(width: 100, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Container(width: 60, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
