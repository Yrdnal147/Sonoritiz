import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../core/widgets/sonoritiz_fast_scrollbar.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../../core/widgets/track_grid_view.dart';
import '../../offline/presentation/cubit/download_cubit.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import 'cubit/library_cubit.dart';
import 'cubit/library_state.dart';
import 'cubit/library_ui_cubit.dart';

class LikedTracksScreen extends StatefulWidget {
  const LikedTracksScreen({super.key});

  @override
  State<LikedTracksScreen> createState() => _LikedTracksScreenState();
}

class _LikedTracksScreenState extends State<LikedTracksScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedArtist;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> _extractTopArtists(List<TrackModel> tracks) {
    final counts = <String, int>{};
    final display = <String, String>{};
    for (final t in tracks) {
      final primary = t.artistName
          .split(RegExp(r'\s*(?:,|feat\.?|ft\.?|&)\s*', caseSensitive: false))
          .first
          .trim();
      if (primary.isEmpty || primary.toLowerCase() == 'inconnu') continue;
      final key = primary.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
      display.putIfAbsent(key, () => primary);
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(10)
        .map((e) => display[e.key] ?? e.key)
        .toList(growable: false);
  }

  List<TrackModel> _filterFavorites(List<TrackModel> raw) {
    return raw.where((t) {
      if (_selectedArtist != null && _selectedArtist!.isNotEmpty) {
        if (!t.artistName
            .toLowerCase()
            .contains(_selectedArtist!.toLowerCase())) {
          return false;
        }
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        return t.title.toLowerCase().contains(q) ||
            t.artistName.toLowerCase().contains(q) ||
            t.albumName.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  void _downloadAllFavorites(
    BuildContext context,
    List<TrackModel> tracksToDownload,
  ) {
    if (tracksToDownload.isEmpty) return;
    HapticFeedback.mediumImpact();
    final dlCubit = context.read<DownloadCubit>();
    int queuedCount = 0;
    for (final t in tracksToDownload) {
      if (!t.id.startsWith('local_')) {
        dlCubit.downloadTrack(t);
        queuedCount++;
      }
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF181820),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Téléchargement hors-ligne lancé pour $queuedCount titres likés !',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, libState) {
        final favorites = libState is LibraryLoaded
            ? libState.favorites
            : const <TrackModel>[];
        final heroCover = favorites.isNotEmpty ? favorites.first.coverUrl : '';
        final topArtists = _extractTopArtists(favorites);
        final filteredFavorites = _filterFavorites(favorites);

        return Scaffold(
          backgroundColor: Colors.black,
          body: SonoritizCoverAtmosphere(
            coverUrl: heroCover,
            child: SafeArea(
              child: BlocBuilder<LibraryUiCubit, LibraryUiState>(
                builder: (context, uiState) {
                  final sortMode = uiState.getSortModeFor('favorites');
                  final viewMode = uiState.getViewModeFor('favorites');
                  final sortedFavorites =
                      TrackGridView.sortTracks(filteredFavorites, sortMode);

                  return Column(
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
                          title: 'Sons likés',
                          fontSize: 22,
                        ),
                        actions: [
                          if (favorites.isNotEmpty)
                            IconButton(
                              tooltip: 'Tout télécharger hors-ligne',
                              icon: const Icon(
                                Icons.download_for_offline_outlined,
                                color: AppColors.primary,
                              ),
                              onPressed: () => _downloadAllFavorites(
                                context,
                                sortedFavorites,
                              ),
                            ),
                          IconButton(
                            tooltip: sortMode == SortMode.recent
                                ? 'Tri : Plus récent'
                                : 'Tri : A-Z',
                            icon: Icon(
                              sortMode == SortMode.recent
                                  ? Icons.schedule_rounded
                                  : Icons.sort_by_alpha_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => context
                                .read<LibraryUiCubit>()
                                .setSortMode(
                                  sortMode == SortMode.recent
                                      ? SortMode.alpha
                                      : SortMode.recent,
                                  tabKey: 'favorites',
                                ),
                          ),
                          PopupMenuButton<ViewMode>(
                            icon: const Icon(
                              Icons.grid_view_rounded,
                              color: Colors.white,
                            ),
                            color: const Color(0xFF181820),
                            onSelected: (mode) => context
                                .read<LibraryUiCubit>()
                                .setViewMode(mode, tabKey: 'favorites'),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: ViewMode.list,
                                child: Text(
                                  'Liste',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              PopupMenuItem(
                                value: ViewMode.listCompact,
                                child: Text(
                                  'Liste compacte',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              PopupMenuItem(
                                value: ViewMode.gridMedium,
                                child: Text(
                                  'Grille',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              PopupMenuItem(
                                value: ViewMode.cards,
                                child: Text(
                                  'Cartes',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Expanded(
                        child: favorites.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 36,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 88,
                                        height: 88,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.favorite_border_rounded,
                                          size: 42,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      const Text(
                                        "Aucun son liké",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Like tes titres favoris ou un album entier pour constituer ta collection.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.6),
                                          fontSize: 13.5,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SonoritizFastScrollbar(
                                itemCount: sortedFavorites.length,
                                bottomMargin: 120,
                                labelBuilder: (idx) {
                                  if (sortedFavorites.isEmpty) return '';
                                  final t = sortedFavorites[
                                      idx.clamp(0, sortedFavorites.length - 1)];
                                  if (sortMode == SortMode.alpha &&
                                      t.title.trim().isNotEmpty) {
                                    final c = t.title.trim()[0].toUpperCase();
                                    return RegExp(r'[A-ZÀ-Ÿ0-9]').hasMatch(c)
                                        ? c
                                        : '#';
                                  }
                                  return '${idx + 1}';
                                },
                                child: CustomScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  slivers: [
                                    // Barre de recherche interne + Pilules de filtre par artiste
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          6,
                                          16,
                                          8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              height: 42,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.07),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.10),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.search_rounded,
                                                    color: Colors.white
                                                        .withValues(alpha: 0.5),
                                                    size: 19,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: TextField(
                                                      controller: _searchCtrl,
                                                      onChanged: (v) =>
                                                          setState(() =>
                                                              _searchQuery = v),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13.8,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      decoration:
                                                          InputDecoration(
                                                        hintText:
                                                            'Rechercher dans vos sons likés...',
                                                        hintStyle: TextStyle(
                                                          color: Colors.white
                                                              .withValues(
                                                                  alpha: 0.38),
                                                          fontSize: 13.5,
                                                        ),
                                                        border:
                                                            InputBorder.none,
                                                        isDense: true,
                                                      ),
                                                    ),
                                                  ),
                                                  if (_searchQuery.isNotEmpty)
                                                    GestureDetector(
                                                      onTap: () {
                                                        _searchCtrl.clear();
                                                        setState(() =>
                                                            _searchQuery = '');
                                                      },
                                                      child: const Icon(
                                                        Icons.close_rounded,
                                                        color: Colors.white54,
                                                        size: 18,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (topArtists.length >= 2) ...[
                                              const SizedBox(height: 10),
                                              SizedBox(
                                                height: 32,
                                                child: ListView.separated(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  physics:
                                                      const BouncingScrollPhysics(),
                                                  itemCount:
                                                      topArtists.length + 1,
                                                  separatorBuilder: (_, __) =>
                                                      const SizedBox(width: 7),
                                                  itemBuilder:
                                                      (context, index) {
                                                    final isAll = index == 0;
                                                    final label = isAll
                                                        ? 'Tous'
                                                        : topArtists[index - 1];
                                                    final isSelected = isAll
                                                        ? _selectedArtist ==
                                                            null
                                                        : _selectedArtist ==
                                                            label;
                                                    return GestureDetector(
                                                      onTap: () {
                                                        HapticFeedback
                                                            .selectionClick();
                                                        setState(() {
                                                          _selectedArtist =
                                                              isAll
                                                                  ? null
                                                                  : (isSelected
                                                                      ? null
                                                                      : label);
                                                        });
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 12,
                                                          vertical: 5,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: isSelected
                                                              ? AppColors
                                                                  .primary
                                                              : Colors.white
                                                                  .withValues(
                                                                      alpha:
                                                                          0.07),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(16),
                                                          border: Border.all(
                                                            color: isSelected
                                                                ? AppColors
                                                                    .primary
                                                                : Colors.white
                                                                    .withValues(
                                                                        alpha:
                                                                            0.12),
                                                          ),
                                                        ),
                                                        alignment:
                                                            Alignment.center,
                                                        child: Text(
                                                          label,
                                                          style: TextStyle(
                                                            color: isSelected
                                                                ? Colors.black
                                                                : Colors.white,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                isSelected
                                                                    ? FontWeight
                                                                        .w800
                                                                    : FontWeight
                                                                        .w600,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          6,
                                          16,
                                          12,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              "${sortedFavorites.length} ${sortedFavorites.length > 1 ? 'titres' : 'titre'}",
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.6),
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const Spacer(),
                                            if (sortedFavorites.isNotEmpty) ...[
                                              GestureDetector(
                                                onTap: () {
                                                  final shuffled =
                                                      List<TrackModel>.from(
                                                          sortedFavorites)
                                                        ..shuffle();
                                                  context
                                                      .read<PlayerCubit>()
                                                      .playTrack(
                                                        shuffled.first,
                                                        queue: shuffled,
                                                        source:
                                                            'vos sons likés',
                                                      );
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 15,
                                                    vertical: 9,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            24),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.16),
                                                    ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.shuffle_rounded,
                                                        color: Colors.white,
                                                        size: 18,
                                                      ),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        "Aléatoire",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              GestureDetector(
                                                onTap: () {
                                                  context
                                                      .read<PlayerCubit>()
                                                      .playTrack(
                                                        sortedFavorites.first,
                                                        queue: sortedFavorites,
                                                        source:
                                                            'vos sons likés',
                                                      );
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 18,
                                                    vertical: 9,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            24),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .play_arrow_rounded,
                                                        color: Colors.black,
                                                        size: 20,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        "Lire",
                                                        style: TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    TrackGridView(
                                      key: ValueKey(
                                        'liked_${viewMode.name}_${sortMode.name}_${_selectedArtist ?? "all"}_$_searchQuery',
                                      ),
                                      tracks: filteredFavorites,
                                      viewMode: viewMode,
                                      sortMode: sortMode,
                                      playbackSource: 'vos sons likés',
                                    ),
                                    const SliverToBoxAdapter(
                                      child: SizedBox(height: 130),
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
      },
    );
  }
}
