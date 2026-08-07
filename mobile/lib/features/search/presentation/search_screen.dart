import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../../../core/theme/app_colors.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/track_context_menu.dart';
import 'cubit/search_cubit.dart';
import 'cubit/search_state.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    // Ensures we start in initial state when returning
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (context, state) {
                  if (state is SearchInitial) {
                    return _buildInitialState(state.recentSearches);
                  } else if (state is SearchLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  } else if (state is SearchSuccess) {
                    return _buildSearchResults(state.results, state.query);
                  } else if (state is SearchError) {
                    return Center(
                      child: Text(state.message, style: const TextStyle(color: AppColors.error)),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
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
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: "Que souhaitez-vous écouter ?",
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear_rounded, color: Colors.white54),
            onPressed: () {
              _searchController.clear();
              context.read<SearchCubit>().resetSearch();
              _focusNode.unfocus();
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildInitialState(List<String> recentSearches) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Recherches récentes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                TextButton(
                  onPressed: () => context.read<SearchCubit>().clearHistory(),
                  child: const Text("Effacer", style: TextStyle(color: Colors.white54)),
                )
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentSearches.map((term) {
                return InkWell(
                  onTap: () {
                    _searchController.text = term;
                    _onSearchSubmitted(term);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(term, style: const TextStyle(color: Colors.white)),
                  ),
                );
              }).toList(),
            ).animate().fadeIn(),
            const SizedBox(height: 32),
          ],
          const Text("Tout explorer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: ResponsiveUtils.getGridCrossAxisCount(context),
            childAspectRatio: 1.6,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
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

  Widget _buildSpotifyGenreCard(String name, List<Color> colors) {
    return GestureDetector(
      onTap: () {
        _searchController.text = name;
        _onSearchSubmitted(name);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
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
              padding: const EdgeInsets.all(12.0),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white54, size: 40),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(List<TrackModel> results, String query) {
    if (results.isEmpty) {
      return Center(
        child: Text("Aucun résultat pour \"$query\"", style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    final bestMatch = results.first;
    final otherResults = results.length > 1 ? results.sublist(1) : <TrackModel>[];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      physics: const BouncingScrollPhysics(),
      children: [
        const Text("Meilleur résultat", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildBestMatchCard(bestMatch, results),
        if (otherResults.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text("Titres", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...otherResults.map((track) => _buildResultTile(track, results)).toList(),
        ],
        const SizedBox(height: 100),
      ],
    ).animate().fadeIn();
  }

  Widget _buildBestMatchCard(TrackModel track, List<TrackModel> queue) {
    return GestureDetector(
      onTap: () => context.read<PlayerCubit>().playTrack(track, queue: queue),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: track.coverUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: track.coverUrl, width: 80, height: 80, fit: BoxFit.cover)
                  : Container(width: 80, height: 80, color: AppColors.surfaceLight, child: const Icon(Icons.music_note)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                        child: const Text("Titre", style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(track.artistName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
            const CircleAvatar(
              backgroundColor: AppColors.primary,
              radius: 24,
              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(TrackModel track, List<TrackModel> queue) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: track.coverUrl.isNotEmpty
            ? CachedNetworkImage(imageUrl: track.coverUrl, width: 50, height: 50, fit: BoxFit.cover)
            : Container(width: 50, height: 50, color: AppColors.surface, child: const Icon(Icons.music_note, color: Colors.white70)),
      ),
      title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(track.artistName, style: const TextStyle(color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, color: Colors.white54),
        onPressed: () {
          TrackContextMenu.show(context, track);
        },
      ),
      onTap: () {
        context.read<PlayerCubit>().playTrack(track, queue: queue);
      },
    );
  }
}
