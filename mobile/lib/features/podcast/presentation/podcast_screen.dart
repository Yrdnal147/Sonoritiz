import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/sonoritiz_artwork.dart';
import '../../../../core/widgets/sonoritiz_dynamic_background.dart';
import '../../../../core/widgets/sonoritiz_page_title.dart';
import '../../home/data/repositories/catalog_repository.dart';
import '../../home/presentation/cubit/home_cubit.dart';
import '../../player/data/models/track_model.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => _PodcastScreenState();
}

class _PodcastScreenState extends State<PodcastScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  List<TrackModel> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  int _requestSeq = 0;
  String _selectedThemeId = 'all';
  String _activeQuery = '';
  String _activeType = 'all';
  static const int _pageSize = 40;

  static const List<Map<String, String>> _themes = [
    {'id': 'all', 'label': 'À la une', 'query': '', 'type': 'all'},
    {'id': 'amour', 'label': 'Amour & Relations', 'query': 'amour couple relations sentimentales histoire d amour', 'type': 'podcast'},
    {'id': 'musique', 'label': 'Musique & Interviews', 'query': 'interview artiste musique rap afro podcast', 'type': 'podcast'},
    {'id': 'afrique', 'label': 'Afrique & Société', 'query': 'afrique culture société interview débat', 'type': 'podcast'},
    {'id': 'crime', 'label': 'Enquêtes & True Crime', 'query': 'enquête histoire vraie affaire criminelle récit', 'type': 'podcast'},
    {'id': 'foot', 'label': 'Football & Sport', 'query': 'football sport after foot débrief', 'type': 'podcast'},
    {'id': 'business', 'label': 'Business & Tech', 'query': 'business entrepreneuriat tech intelligence artificielle', 'type': 'podcast'},
    {'id': 'books', 'label': 'Livres Audio', 'query': 'livre audio roman complet', 'type': 'audiobook'},
    {'id': 'histoire', 'label': 'Histoire & Récits', 'query': 'histoire culture récit documentaire', 'type': 'podcast'},
    {'id': 'science', 'label': 'Sciences & Découvertes', 'query': 'science espace univers découverte documentaire', 'type': 'podcast'},
    {'id': 'humour', 'label': 'Humour & Stand-up', 'query': 'humour comédie stand up spectacle podcast', 'type': 'podcast'},
    {'id': 'dev', 'label': 'Développement & Philo', 'query': 'développement personnel philosophie psychologie', 'type': 'all'},
  ];

  String _formatEpisodeDuration(int seconds) {
    if (seconds <= 0) return '';
    final int hours = seconds ~/ 3600;
    final int mins = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${mins.toString().padLeft(2, '0')}m';
    }
    return '$mins min';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchPodcasts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 280 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  late final CatalogRepository _fallbackRepository = CatalogRepository();

  CatalogRepository _resolveRepository() {
    try {
      return context.read<CatalogRepository>();
    } catch (_) {
      try {
        return context.read<HomeCubit>().catalogRepository;
      } catch (_) {
        return _fallbackRepository;
      }
    }
  }

  Future<void> _fetchPodcasts({
    String query = '',
    String type = 'all',
  }) async {
    if (!mounted) return;
    final int seq = ++_requestSeq;
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _offset = 0;
      _activeQuery = query;
      _activeType = type;
    });
    try {
      final repo = _resolveRepository();
      final results = await repo.getPodcasts(
        query: query,
        type: type,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _items = results;
        _offset = _pageSize;
        _hasMore = results.length >= 12;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!mounted || _isLoadingMore || !_hasMore) return;
    final int seq = _requestSeq;
    setState(() => _isLoadingMore = true);
    try {
      final repo = _resolveRepository();
      final more = await repo.getPodcasts(
        query: _activeQuery,
        type: _activeType,
        limit: _pageSize,
        offset: _offset,
      );
      if (!mounted || seq != _requestSeq) return;
      final existingIds = _items.map((e) => e.id).toSet();
      final existingTitles = _items.map((e) => e.title.trim().toLowerCase()).toSet();
      final fresh = more.where((item) {
        return !existingIds.contains(item.id) &&
            !existingTitles.contains(item.title.trim().toLowerCase());
      }).toList();
      setState(() {
        _items = [..._items, ...fresh];
        _offset += _pageSize;
        _hasMore = more.length >= 10 && fresh.isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        final theme = _themes.firstWhere(
          (t) => t['id'] == _selectedThemeId,
          orElse: () => _themes.first,
        );
        _fetchPodcasts(
          query: theme['query'] ?? '',
          type: theme['type'] ?? 'all',
        );
      } else {
        _fetchPodcasts(query: trimmed, type: 'all');
      }
    });
  }

  void _selectTheme(Map<String, String> theme) {
    setState(() {
      _selectedThemeId = theme['id']!;
      _searchController.clear();
    });
    _fetchPodcasts(
      query: theme['query'] ?? '',
      type: theme['type'] ?? 'all',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SonoritizDynamicBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header avec retour + SonoritizPageTitle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
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
                          child: SonoritizPageTitle(title: "Podcasts & Livres"),
                        ),
                      ],
                    ),
                  ),

                  // Barre de recherche thématique
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: (value) => _fetchPodcasts(
                          query: value.trim(),
                          type: 'all',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: "Amour, couple, musique, sport, livre audio...",
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.38),
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.white.withValues(alpha: 0.65),
                            size: 22,
                          ),
                          suffixIcon: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _searchController,
                            builder: (context, val, _) {
                              if (val.text.isEmpty) return const SizedBox.shrink();
                              return IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  size: 19,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              );
                            },
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Filtres thématiques rapides (Foot, Livres Audio, Histoire, Business...)
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _themes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final theme = _themes[index];
                        final isSelected = _selectedThemeId == theme['id'] &&
                            _searchController.text.trim().isEmpty;

                        return GestureDetector(
                          onTap: () => _selectTheme(theme),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              theme['label']!,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Grille des résultats Podcasts & Livres Audio
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2.5,
                            ),
                          )
                        : _items.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Text(
                                    "Aucun podcast ou livre audio trouvé pour cette recherche.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.55),
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                              )
                            : CustomScrollView(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        AppDimensions.spacingMd,
                                        0,
                                        AppDimensions.spacingMd,
                                        10,
                                      ),
                                      child: Text(
                                        _activeQuery.isEmpty
                                            ? "${_items.length} podcasts & livres"
                                            : "${_items.length} résultats pour « $_activeQuery »",
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.58),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppDimensions.spacingMd,
                                      4,
                                      AppDimensions.spacingMd,
                                      24,
                                    ),
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
                                        childAspectRatio: 0.74,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 18,
                                      ),
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final item = _items[index];
                                          final isBook = item.genre.toLowerCase().contains('livre');
                                          final isVideoEpisode =
                                              !item.id.startsWith('deezer_') ||
                                                  item.genre
                                                      .toLowerCase()
                                                      .contains('vidéo');
                                          final durationLabel =
                                              _formatEpisodeDuration(
                                                  item.durationSeconds);

                                          return GestureDetector(
                                            onTap: () {
                                              context.push('/podcast_player', extra: item);
                                            },
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius: BorderRadius.circular(14),
                                                        child: item.coverUrl.isNotEmpty
                                                            ? SonoritizArtwork(
                                                                imageUrl: item.coverUrl,
                                                                width: double.infinity,
                                                                height: double.infinity,
                                                                borderRadius: 14,
                                                                fit: BoxFit.cover,
                                                              )
                                                            : Container(
                                                                color: const Color(0xFF1C1C22),
                                                                child: const Icon(
                                                                  Icons.podcasts_rounded,
                                                                  color: Colors.white24,
                                                                  size: 40,
                                                                ),
                                                              ),
                                                      ),
                                                      Positioned(
                                                        top: 8,
                                                        left: 8,
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 3.5,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: isVideoEpisode
                                                                ? AppColors.primary
                                                                : Colors.black.withValues(alpha: 0.72),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              if (isVideoEpisode) ...[
                                                                const Icon(
                                                                  Icons.videocam_rounded,
                                                                  color: Colors.black,
                                                                  size: 12,
                                                                ),
                                                                const SizedBox(width: 4),
                                                              ],
                                                              Text(
                                                                isVideoEpisode
                                                                    ? (isBook ? "Livre Vidéo" : "Podcast Vidéo")
                                                                    : (isBook ? "Livre audio" : "Podcast"),
                                                                style: TextStyle(
                                                                  color: isVideoEpisode
                                                                      ? Colors.black
                                                                      : Colors.white,
                                                                  fontSize: 10.5,
                                                                  fontWeight: FontWeight.w800,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      if (durationLabel.isNotEmpty)
                                                        Positioned(
                                                          bottom: 8,
                                                          right: 8,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(
                                                              horizontal: 7,
                                                              vertical: 3,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color: Colors.black.withValues(alpha: 0.78),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Text(
                                                              durationLabel,
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 10.5,
                                                                fontWeight: FontWeight.w700,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  item.title,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -0.2,
                                                    height: 1.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  item.artistName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.5),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        childCount: _items.length,
                                      ),
                                    ),
                                  ),
                                  if (_isLoadingMore)
                                    const SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        child: Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: AppColors.primary,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                                ],
                              ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
