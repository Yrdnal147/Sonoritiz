import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/widgets/sonoritiz_dynamic_background.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import 'cubit/library_cubit.dart';
import 'cubit/library_state.dart';
import 'cubit/library_ui_cubit.dart';
import 'favorites_screen.dart';
import 'playlists_list_screen.dart';
import 'history_screen.dart';
import 'downloads_screen.dart';
import 'local_audio_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  static const List<_LibraryTabSpec> _tabs = [
    _LibraryTabSpec(
      id: 'favorites',
      label: 'Favoris',
      icon: Icons.favorite_rounded,
    ),
    _LibraryTabSpec(
      id: 'playlists',
      label: 'Playlists',
      icon: Icons.queue_music_rounded,
    ),
    _LibraryTabSpec(
      id: 'history',
      label: 'Historique',
      icon: Icons.history_rounded,
    ),
    _LibraryTabSpec(
      id: 'downloads',
      label: 'Téléchargements',
      icon: Icons.download_done_rounded,
    ),
    _LibraryTabSpec(
      id: 'local',
      label: 'Sons internes',
      icon: Icons.folder_special_rounded,
    ),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final uiCubit = context.read<LibraryUiCubit>();
    final initialIndex = uiCubit.activeTabIndex;
    if (uiCubit.state.searchQuery.isNotEmpty) {
      _searchController.text = uiCubit.state.searchQuery;
    }
    _tabController = TabController(
      length: _tabs.length,
      initialIndex: initialIndex,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!mounted) return;
    if (!_tabController.indexIsChanging) {
      context.read<LibraryUiCubit>().setActiveTab(_tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _searchHintForTab(String tabId) {
    switch (tabId) {
      case 'downloads':
        return "Titre, album ou artiste téléchargé...";
      case 'local':
        return "Titre ou artiste local...";
      case 'favorites':
        return "Rechercher un titre, album ou artiste favori...";
      case 'playlists':
        return "Rechercher une playlist...";
      case 'history':
        return "Rechercher dans l'historique...";
      default:
        return "Rechercher dans la bibliothèque...";
    }
  }

  IconData _iconForViewMode(ViewMode mode) {
    switch (mode) {
      case ViewMode.list:
        return Icons.view_list_rounded;
      case ViewMode.listCompact:
        return Icons.density_small_rounded;
      case ViewMode.gridSmall:
        return Icons.grid_on_rounded;
      case ViewMode.gridMedium:
        return Icons.grid_view_rounded;
      case ViewMode.gridLarge:
        return Icons.crop_square_rounded;
      case ViewMode.cards:
        return Icons.view_carousel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocConsumer<LibraryUiCubit, LibraryUiState>(
      listenWhen: (prev, curr) =>
          prev.searchQuery != curr.searchQuery ||
          prev.isSearchActive != curr.isSearchActive ||
          prev.activeTabId != curr.activeTabId,
      listener: (context, uiState) {
        if (!uiState.isSearchActive || uiState.searchQuery.isEmpty) {
          if (_searchController.text.isNotEmpty && uiState.searchQuery.isEmpty) {
            _searchController.clear();
          }
        }
        final targetIdx = LibraryUiCubit.tabIds.indexOf(uiState.activeTabId);
        if (targetIdx >= 0 && _tabController.index != targetIdx) {
          _tabController.animateTo(targetIdx);
        }
      },
      builder: (context, uiState) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SonoritizDynamicBackground(
            child: SafeArea(
              bottom: false,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      backgroundColor: innerBoxIsScrolled
                          ? const Color(0xFF0B0B0F).withValues(alpha: 0.92)
                          : Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      pinned: true,
                      floating: true,
                      centerTitle: false,
                      toolbarHeight: 66,
                      titleSpacing: AppDimensions.spacingMd,
                      title: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: uiState.isSearchActive
                            ? Container(
                                key: const ValueKey('lib_search_field'),
                                height: 42,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF15151C),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.35),
                                    width: 1.0,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      size: 18,
                                      color: AppColors.primary
                                          .withValues(alpha: 0.9),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        autofocus: true,
                                        textInputAction: TextInputAction.search,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: _searchHintForTab(
                                            uiState.activeTabId,
                                          ),
                                          hintStyle: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.42),
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          isDense: true,
                                          filled: false,
                                        ),
                                        onChanged: (value) {
                                          context
                                              .read<LibraryUiCubit>()
                                              .updateSearchQuery(value);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const Align(
                                key: ValueKey('lib_page_title'),
                                alignment: Alignment.centerLeft,
                                child: SonoritizPageTitle(
                                  title: "Ma Bibliothèque",
                                ),
                              ),
                      ),
                      actions: [
                        _GlassHeaderIconButton(
                          icon: uiState.isSearchActive
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          tooltip: uiState.isSearchActive
                              ? "Fermer la recherche"
                              : "Rechercher",
                          isActive: uiState.isSearchActive,
                          onTap: () {
                            if (uiState.isSearchActive) {
                              _searchController.clear();
                              context.read<LibraryUiCubit>().closeSearch();
                            } else {
                              context.read<LibraryUiCubit>().toggleSearch();
                            }
                          },
                        ),
                        if (!uiState.isSearchActive) ...[
                          const SizedBox(width: 8),
                          _GlassHeaderIconButton(
                            icon: uiState.currentSortMode == SortMode.alpha
                                ? Icons.sort_by_alpha_rounded
                                : Icons.schedule_rounded,
                            tooltip: uiState.currentSortMode == SortMode.alpha
                                ? "Tri alphabétique"
                                : "Tri par récence",
                            onTap: () =>
                                context.read<LibraryUiCubit>().toggleSortMode(),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<ViewMode>(
                            tooltip: "Mode d'affichage",
                            offset: const Offset(0, 44),
                            color: const Color(0xFF15151C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            onSelected: (mode) => context
                                .read<LibraryUiCubit>()
                                .setViewMode(mode),
                            itemBuilder: (context) => [
                              _buildViewMenuItem(
                                context,
                                ViewMode.list,
                                Icons.view_list_rounded,
                                "Liste",
                                uiState.currentViewMode,
                              ),
                              _buildViewMenuItem(
                                context,
                                ViewMode.listCompact,
                                Icons.density_small_rounded,
                                "Liste compacte",
                                uiState.currentViewMode,
                              ),
                              _buildViewMenuItem(
                                context,
                                ViewMode.gridSmall,
                                Icons.grid_on_rounded,
                                "Petite grille",
                                uiState.currentViewMode,
                              ),
                              _buildViewMenuItem(
                                context,
                                ViewMode.gridMedium,
                                Icons.grid_view_rounded,
                                "Grille",
                                uiState.currentViewMode,
                              ),
                              _buildViewMenuItem(
                                context,
                                ViewMode.gridLarge,
                                Icons.crop_square_rounded,
                                "Grande grille",
                                uiState.currentViewMode,
                              ),
                              _buildViewMenuItem(
                                context,
                                ViewMode.cards,
                                Icons.view_carousel_rounded,
                                "Cartes",
                                uiState.currentViewMode,
                              ),
                            ],
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF15151C),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.11),
                                ),
                              ),
                              child: Icon(
                                _iconForViewMode(uiState.currentViewMode),
                                color: Colors.white,
                                size: 18.5,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: AppDimensions.spacingMd),
                      ],
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(54),
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: innerBoxIsScrolled ? 16 : 0,
                              sigmaY: innerBoxIsScrolled ? 16 : 0,
                            ),
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(bottom: 8, top: 2),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withValues(
                                      alpha: innerBoxIsScrolled ? 0.08 : 0.04,
                                    ),
                                  ),
                                ),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                labelPadding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                indicatorSize: TabBarIndicatorSize.tab,
                                indicator: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.24),
                                      AppColors.primary.withValues(alpha: 0.12),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.58),
                                    width: 1.1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.16),
                                      blurRadius: 12,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                indicatorPadding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                labelColor: Colors.white,
                                unselectedLabelColor:
                                    Colors.white.withValues(alpha: 0.56),
                                labelStyle: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  letterSpacing: -0.2,
                                ),
                                unselectedLabelStyle:
                                    textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.2,
                                  letterSpacing: -0.1,
                                ),
                                dividerColor: Colors.transparent,
                                splashBorderRadius: BorderRadius.circular(24),
                                tabs: _tabs.map((tab) {
                                  final isSelected =
                                      uiState.activeTabId == tab.id;
                                  return Tab(
                                    height: 42,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 13,
                                      ),
                                      decoration: isSelected
                                          ? null
                                          : BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.045),
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.07),
                                              ),
                                            ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            tab.icon,
                                            size: 15.5,
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.white
                                                    .withValues(alpha: 0.52),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(tab.label),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ];
                },
                body: BlocBuilder<LibraryCubit, LibraryState>(
                  builder: (context, state) {
                    if (state is LibraryLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2.5,
                        ),
                      );
                    }

                    if (state is LibraryError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: AppDimensions.iconXxl,
                              color: colorScheme.error,
                            ),
                            const SizedBox(height: AppDimensions.spacingMd),
                            Text(state.message, style: textTheme.bodyLarge),
                            const SizedBox(height: AppDimensions.spacingLg),
                            ElevatedButton(
                              onPressed: () => context
                                  .read<LibraryCubit>()
                                  .loadLibraryData(),
                              child: const Text("Réessayer"),
                            ),
                          ],
                        ),
                      );
                    }

                    if (state is LibraryLoaded) {
                      final query =
                          LibraryUiCubit.normalizeForSearch(uiState.searchQuery);

                      final filteredFavorites = query.isEmpty
                          ? state.favorites
                          : state.favorites
                              .where((t) =>
                                  LibraryUiCubit.normalizeForSearch(t.title)
                                      .contains(query) ||
                                  LibraryUiCubit.normalizeForSearch(
                                          t.artistName)
                                      .contains(query))
                              .toList();

                      final filteredPlaylists = query.isEmpty
                          ? state.playlists
                          : state.playlists
                              .where((p) =>
                                  LibraryUiCubit.normalizeForSearch(p.name)
                                      .contains(query))
                              .toList();

                      final filteredHistory = query.isEmpty
                          ? state.history
                          : state.history.where((h) {
                              if (h.track != null) {
                                return LibraryUiCubit.normalizeForSearch(
                                            h.track!.title)
                                        .contains(query) ||
                                    LibraryUiCubit.normalizeForSearch(
                                            h.track!.artistName)
                                        .contains(query);
                              }
                              return LibraryUiCubit.normalizeForSearch(
                                      h.trackId)
                                  .contains(query);
                            }).toList();

                      return TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          FavoritesScreen(favorites: filteredFavorites),
                          PlaylistsListScreen(playlists: filteredPlaylists),
                          HistoryScreen(history: filteredHistory),
                          const DownloadsScreen(),
                          LocalAudioScreen(
                            storageService:
                                context.read<LibraryUiCubit>().storageService,
                          ),
                        ],
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<ViewMode> _buildViewMenuItem(
    BuildContext context,
    ViewMode mode,
    IconData icon,
    String title,
    ViewMode currentMode,
  ) {
    final isSelected = mode == currentMode;

    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.8),
            size: AppDimensions.iconSm,
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Text(
            title,
            style: TextStyle(
              color: isSelected ? AppColors.primary : Colors.white,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryTabSpec {
  final String id;
  final String label;
  final IconData icon;

  const _LibraryTabSpec({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class _GlassHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  const _GlassHeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.18)
                : const Color(0xFF15151C),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.11),
            ),
          ),
          child: Icon(
            icon,
            color: isActive ? AppColors.primary : Colors.white,
            size: 19,
          ),
        ),
      ),
    );
  }
}
