import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/widgets/artist_name_display.dart';
import '../../../core/widgets/sonoritiz_track_tile.dart';
import '../../../core/widgets/sonoritiz_icon_button.dart';
import '../../../core/widgets/sonoritiz_artwork.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/track_context_menu.dart';
import 'cubit/search_cubit.dart';
import 'cubit/search_state.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/widgets/festive_background.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    context.read<SearchCubit>().resetSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<SearchCubit>().search(query, isDebounced: true);
  }

  void _onSearchSubmitted(String query) {
    context.read<SearchCubit>().search(query, isDebounced: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FestiveBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: BlocBuilder<SearchCubit, SearchState>(
                  builder: (context, state) {
                    if (state is SearchInitial) {
                      return _buildInitialState(state.recentSearches);
                    } else if (state is SearchLoading) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (state is SearchSuccess) {
                      return _buildSearchResults(state.results, state.query);
                    } else if (state is SearchError) {
                      return Center(
                        child: Text(state.message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppDimensions.spacingMd, AppDimensions.spacingLg, AppDimensions.spacingMd, AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        onChanged: _onSearchChanged,
        onSubmitted: _onSearchSubmitted,
        decoration: InputDecoration(
          hintText: "Que souhaitez-vous écouter ?",
          prefixIcon: Icon(Icons.search_rounded, color: colorScheme.primary),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear_rounded, color: colorScheme.onSurfaceVariant),
            onPressed: () {
              _searchController.clear();
              context.read<SearchCubit>().resetSearch();
              _focusNode.unfocus();
            },
          ),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingMd),
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildInitialState(List<String> recentSearches) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Recherches récentes", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => context.read<SearchCubit>().clearHistory(),
                  child: Text("Effacer", style: TextStyle(color: colorScheme.onSurfaceVariant)),
                )
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Wrap(
              spacing: AppDimensions.spacingSm,
              runSpacing: AppDimensions.spacingSm,
              children: recentSearches.map((term) {
                return InkWell(
                  onTap: () {
                    _searchController.text = term;
                    _onSearchSubmitted(term);
                  },
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd, vertical: AppDimensions.spacingSm),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                      border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                    ),
                    child: Text(term, style: textTheme.bodyMedium),
                  ),
                );
              }).toList(),
            ).animate().fadeIn(),
            const SizedBox(height: AppDimensions.spacingXl),
          ],
          Text("Viens à la découverte de nouvelles sonorités", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppDimensions.spacingMd),
          _buildDiscoveryCards(context),
          const SizedBox(height: AppDimensions.spacingXl),
          Text("Tout explorer", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppDimensions.spacingMd),
          GridView.count(
            crossAxisCount: ResponsiveUtils.getGridCrossAxisCount(context),
            childAspectRatio: 1.6,
            crossAxisSpacing: AppDimensions.spacingMd,
            mainAxisSpacing: AppDimensions.spacingMd,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildSpotifyGenreCard("Rock", const [Color(0xFFE91E63), Color(0xFF9C27B0)]),
              _buildSpotifyGenreCard("Pop", const [Color(0xFF2196F3), Color(0xFF00BCD4)]),
              _buildSpotifyGenreCard("Hip-Hop", const [Color(0xFFFF9800), Color(0xFFFF5722)]),
              _buildSpotifyGenreCard("Jazz", const [Color(0xFF4CAF50), Color(0xFF8BC34A)]),
              _buildSpotifyGenreCard("Electro", const [Color(0xFF673AB7), Color(0xFF3F51B5)]),
              _buildSpotifyGenreCard("Ambient", const [Color(0xFF607D8B), Color(0xFF37474F)]),
            ],
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildDiscoveryCards(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildDiscoveryCard(
            context: context,
            title: "Sonorités en audios",
            icon: Icons.headphones_rounded,
            colors: const [Color(0xFFFF5E5B), Color(0xFFFFAC93)],
            routeType: 'audio',
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          _buildDiscoveryCard(
            context: context,
            title: "Sonorités vidéo",
            icon: Icons.play_circle_filled_rounded,
            colors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
            routeType: 'video',
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          _buildDiscoveryCard(
            context: context,
            title: "Lyrics de sonorité",
            icon: Icons.lyrics_rounded,
            colors: const [Color(0xFF00C9FF), Color(0xFF92FE9D)],
            routeType: 'lyrics',
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _buildDiscoveryCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Color> colors,
    required String routeType,
  }) {
    return GestureDetector(
      onTap: () {
        context.push('/discovery/$routeType');
      },
      child: Container(
        width: 180,
        height: 120,
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: AppDimensions.iconXl),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotifyGenreCard(String name, List<Color> colors) {
    return GestureDetector(
      onTap: () {
        _searchController.text = name;
        _onSearchSubmitted(name);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: [
            BoxShadow(
              color: colors.last.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            Positioned(
              right: -15,
              bottom: -15,
              child: Transform.rotate(
                angle: 0.4,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: const Icon(Icons.music_note_rounded, color: Colors.white54, size: 40),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(List<TrackModel> results, String query) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (results.isEmpty) {
      return Center(
        child: Text("Aucun résultat pour \"$query\"", style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
      );
    }

    final bestMatch = results.first;
    final otherResults = results.length > 1 ? results.sublist(1) : <TrackModel>[];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      physics: const BouncingScrollPhysics(),
      children: [
        Text("Meilleur résultat", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppDimensions.spacingMd),
        _buildBestMatchCard(bestMatch, results),
        if (otherResults.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingXl),
          Text("Titres", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppDimensions.spacingSm),
          ...otherResults.map((track) => _buildResultTile(track, results)).toList(),
        ],
        const SizedBox(height: 100),
      ],
    ).animate().fadeIn();
  }

  Widget _buildBestMatchCard(TrackModel track, List<TrackModel> queue) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => context.read<PlayerCubit>().playTrack(track, queue: queue),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: Row(
          children: [
            SonoritizArtwork(
              imageUrl: track.coverUrl,
              width: 80,
              height: 80,
              borderRadius: AppDimensions.radiusMd,
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: colorScheme.onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text("Titre", style: textTheme.labelSmall),
                      ),
                      const SizedBox(width: AppDimensions.spacingSm),
                      Expanded(
                        child: ArtistNameDisplay(
                          artistName: track.artistName, 
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant), 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CircleAvatar(
              backgroundColor: colorScheme.primary,
              radius: 24,
              child: Icon(Icons.play_arrow_rounded, color: colorScheme.onPrimary, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(TrackModel track, List<TrackModel> queue) {
    final colorScheme = Theme.of(context).colorScheme;

    return SonoritizTrackTile(
      imageUrl: track.coverUrl,
      title: track.title,
      subtitle: track.artistName,
      onTap: () => context.read<PlayerCubit>().playTrack(track, queue: queue),
      trailing: SonoritizIconButton(
        icon: Icons.more_vert_rounded,
        tooltip: "Options",
        color: colorScheme.onSurfaceVariant,
        onPressed: () => TrackContextMenu.show(context, track),
      ),
    );
  }
}
