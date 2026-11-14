import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/artist_name_display.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import 'widgets/sonoritiz_moods_widget.dart';
import '../../../core/widgets/sonoritiz_track_tile.dart';
import '../../../core/widgets/sonoritiz_artwork.dart';
import '../../../core/widgets/sonoritiz_dynamic_background.dart';
import '../../../core/storage/storage_service.dart';
import '../../discovery/presentation/cubit/discovery_cubit.dart';
import '../../discovery/presentation/cubit/discovery_state.dart';
import '../../home/presentation/cubit/home_cubit.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import 'cubit/search_cubit.dart';
import 'cubit/search_state.dart';
import 'widgets/sonoritiz_shorts_preview_row.dart';
import 'widgets/voice_search_bottom_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _searchedArtists = [];
  List<Map<String, dynamic>> _deezerGenres = [];
  bool _isLoadingGenres = true;

  @override
  void initState() {
    super.initState();
    context.read<SearchCubit>().resetSearch();
    final discoveryCubit = context.read<DiscoveryCubit>();
    if (discoveryCubit.state is DiscoveryInitial) {
      discoveryCubit.loadDiscoveryFeeds();
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _searchedArtists = StorageService().getTopSearchedArtists(limit: 14);
    });

    final repo = context.read<SearchCubit>().repository;
    try {
      final cached = await repo.getCachedDeezerGenres();
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _deezerGenres = cached;
          _isLoadingGenres = false;
        });
      }
    } catch (_) {}

    try {
      final genres = await repo.getAllDeezerGenres();
      if (mounted) {
        setState(() {
          if (genres.isNotEmpty) {
            _deezerGenres = genres;
          }
          _isLoadingGenres = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingGenres = false);
      }
    }
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

  void _openVoiceSearch() {
    HomeCubit? homeCubit;
    try {
      homeCubit = context.read<HomeCubit>();
    } catch (_) {}

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final sheet = VoiceSearchBottomSheet(
          onQueryRecognized: (query) {
            _searchController.text = query;
            _onSearchSubmitted(query);
          },
        );
        if (homeCubit != null) {
          return BlocProvider.value(value: homeCubit, child: sheet);
        }
        return sheet;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SonoritizDynamicBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title
              const SonoritizPageTitle(
                title: "Rechercher",
                padding: EdgeInsets.fromLTRB(
                  AppDimensions.spacingMd,
                  AppDimensions.spacingMd,
                  AppDimensions.spacingMd,
                  AppDimensions.spacingXs,
                ),
              ),

              // Search bar with voice search button
              _buildSearchBar(),

              // Search content
              Expanded(
                child: BlocBuilder<SearchCubit, SearchState>(
                  builder: (context, state) {
                    if (state is SearchInitial) {
                      return _buildInitialState(state.recentSearches);
                    } else if (state is SearchLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      );
                    } else if (state is SearchSuccess) {
                      return _buildSearchResults(state.results, state.artists, state.query);
                    } else if (state is SearchError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.spacingXl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 48,
                              ),
                              const SizedBox(height: AppDimensions.spacingMd),
                              Text(
                                state.message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spacingLg),
                              OutlinedButton.icon(
                                onPressed: _searchController.text.trim().isEmpty
                                    ? null
                                    : () => _onSearchSubmitted(
                                          _searchController.text.trim(),
                                        ),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        ),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.spacingMd,
        AppDimensions.spacingSm,
        AppDimensions.spacingMd,
        AppDimensions.spacingMd,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF19191D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        onChanged: _onSearchChanged,
        onSubmitted: _onSearchSubmitted,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: "Artistes, titres, paroles...",
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.primary.withValues(alpha: 0.88),
            size: 23,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      context.read<SearchCubit>().resetSearch();
                      _focusNode.unfocus();
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
                tooltip: "Recherche vocale",
                onPressed: _openVoiceSearch,
              ),
            ],
          ),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 12,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _buildInitialState(List<String> recentSearches) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Recherches récentes
          if (recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recherches récentes",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                TextButton(
                  onPressed: () => context.read<SearchCubit>().clearHistory(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.45),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    "Effacer",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          term,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
          ],

          // Sonoritiz Shorts (aperçus vivants hauteur x3)
          const Text(
            "Sonoritiz Shorts",
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          const SonoritizShortsPreviewRow(),
          const SizedBox(height: 32),

          // 2. Artistes les plus recherchés
          const SonoritizPageTitle(
            title: "Artistes les plus recherchés",
            padding: EdgeInsets.zero,
            fontSize: 20,
          ),
          const SizedBox(height: 14),
          _buildTrendingArtistsRow(context),
          const SizedBox(height: 28),

          // 3. Sonoritiz Moods (10 émotions en bulles flottantes -> playlist sur-mesure)
          const SonoritizMoodsWidget(),
          const SizedBox(height: 28),

          // 5. Genres & Scènes (Grille photographique)
          const Text(
            "Parcourir par genre",
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          _buildPhotographicGenresGrid(),
          const SizedBox(height: 140),
        ],
      ),
    );
  }

  Widget _buildTrendingArtistsRow(BuildContext context) {
    final artistsList = _searchedArtists.isNotEmpty
        ? _searchedArtists
        : StorageService().getTopSearchedArtists(limit: 14);

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: artistsList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final artist = artistsList[index];
          final name = (artist['name'] ?? '').toString();
          final imageUrl = (artist['image'] ?? artist['picture'] ?? artist['picture_medium'] ?? '').toString();
          final artistId = (artist['id'] ?? '').toString();

          return GestureDetector(
            onTap: () {
              StorageService().recordSearchedArtist(artist);
              context.push(
                '/artist',
                extra: {'name': name, 'imageUrl': imageUrl, 'id': artistId},
              );
            },
            child: SizedBox(
              width: 76,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: ClipOval(
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: const Color(0xFF1A1A1A),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFF1A1A1A),
                                alignment: Alignment.center,
                                child: Text(
                                  name.isNotEmpty ? name[0] : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF1A1A1A),
                              alignment: Alignment.center,
                              child: Text(
                                name.isNotEmpty ? name[0] : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
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

  Widget _buildPhotographicGenresGrid() {
    final fallbackGenres = [
      {
        'title': 'Afrobeats',
        'query': 'Afrobeats',
        'color': const Color(0xFFFF5500),
        'image':
            'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/cd/0c/91/cd0c917a-e1a0-2592-a3a1-529796e19ea9/196872682564.jpg/600x600bb.jpg',
      },
      {
        'title': 'Cameroun & 237',
        'query': 'Cameroun Makossa',
        'color': const Color(0xFF00C9FF),
        'image':
            'https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/ec/49/0b/ec490bc4-9cef-e6e9-33b5-6582f684a390/8433391542026.jpg/600x600bb.jpg',
      },
      {
        'title': 'Amapiano',
        'query': 'Amapiano',
        'color': const Color(0xFFE28413),
        'image':
            'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/31/e4/eb/31e4ebf4-97bd-c193-59c7-1b72ed7ab53a/ticket.wlorjbae.jpg/600x600bb.jpg',
      },
      {
        'title': 'Rap & Trap',
        'query': 'Rap Français',
        'color': const Color(0xFF8E2DE2),
        'image':
            'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/ab/c5/ea/abc5eab6-1a33-3910-6f96-3954d76c5815/190295460259.jpg/600x600bb.jpg',
      },
      {
        'title': 'R&B & Soul',
        'query': 'R&B Soul',
        'color': const Color(0xFFFF006E),
        'image':
            'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/c3/59/9a/c3599a96-fb7c-d4f3-c9ce-664128e4e94c/196873703305.jpg/600x600bb.jpg',
      },
      {
        'title': 'Rumba & Ndombolo',
        'query': 'Fally Ipupa Rumba',
        'color': const Color(0xFF2B9348),
        'image':
            'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/62/4d/68/624d681e-dbed-4f2b-4925-487f47692780/5026854850832.jpg/600x600bb.jpg',
      },
      {
        'title': 'Coupé-Décalé & Ivoire',
        'query': 'Didi B Abidjan',
        'color': const Color(0xFFF17F29),
        'image':
            'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/2e/25/c8/2e25c81d-5406-a02d-a2c4-be465678e5f2/cover.jpg/600x600bb.jpg',
      },
      {
        'title': 'Gospel & Louange',
        'query': 'KS Bloom Gospel',
        'color': const Color(0xFF0A369D),
        'image':
            'https://is1-ssl.mzstatic.com/image/thumb/Music122/v4/7a/fa/c8/7afac893-627d-fea0-482e-149af8f7ed2a/cover.jpg/600x600bb.jpg',
      },
    ];

    if (_deezerGenres.isEmpty && _isLoadingGenres) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
        ),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
      );
    }

    final genres = _deezerGenres.isNotEmpty ? _deezerGenres : fallbackGenres;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: genres.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final genre = genres[index];
        final title = genre['title'] as String;
        final imageUrl = genre['image'] as String;

        return GestureDetector(
          onTap: () {
            context.push('/category', extra: genre);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFF1A1A1A),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(
    List<TrackModel> results,
    List<Map<String, dynamic>> artists,
    String query,
  ) {
    if (results.isEmpty && artists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 52,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                "Aucun résultat pour \"$query\"",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Vérifiez l'orthographe ou essayez un autre mot-clé.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bestMatch = results.isNotEmpty ? results.first : null;
    final otherResults = results.length > 1 ? results.sublist(1) : <TrackModel>[];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      physics: const BouncingScrollPhysics(),
      children: [
        if (artists.isNotEmpty) ...[
          const Text(
            "Artiste",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          _buildArtistCard(artists.first),
          const SizedBox(height: 24),
        ],
        if (bestMatch != null) ...[
          Text(
            artists.isEmpty ? "Meilleur résultat" : "Meilleur titre",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          _buildBestMatchCard(bestMatch, results),
        ],
        if (otherResults.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Text(
            "Titres",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          ...otherResults.map((track) => _buildResultTile(track, results)),
        ],
        const SizedBox(height: 120),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildArtistCard(Map<String, dynamic> artist) {
    final imageUrl = (artist['picture'] ?? artist['picture_medium'] ?? '') as String;
    final name = (artist['name'] ?? 'Artiste') as String;
    final int fans = artist['nb_fan'] is int ? artist['nb_fan'] as int : 0;
    final String artistId = (artist['id'] ?? '').toString();

    String fanLabel = "Artiste officiel";
    if (fans >= 1000000) {
      fanLabel = "Artiste officiel • ${(fans / 1000000).toStringAsFixed(1)} M fans";
    } else if (fans >= 1000) {
      fanLabel = "Artiste officiel • ${(fans / 1000).toStringAsFixed(0)} k fans";
    }

    return InkWell(
      onTap: () {
        StorageService().recordSearchedArtist(artist);
        context.push('/artist', extra: {'name': name, 'imageUrl': imageUrl, 'id': artistId});
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: ClipOval(
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFF1E1E1E),
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 24),
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1E1E1E),
                        alignment: Alignment.center,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontSize: 24),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        color: AppColors.primary,
                        size: 17,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    fanLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.35),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestMatchCard(TrackModel track, List<TrackModel> queue) {
    return InkWell(
      onTap: () => context.read<PlayerCubit>().playTrack(track, queue: queue),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SonoritizArtwork(
              imageUrl: track.coverUrl,
              width: 64,
              height: 64,
              borderRadius: 10,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  ArtistNameDisplay(
                    artistName: track.artistName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.black,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(TrackModel track, List<TrackModel> queue) {
    return SonoritizTrackTile(
      track: track,
      queue: queue,
    );
  }
}
