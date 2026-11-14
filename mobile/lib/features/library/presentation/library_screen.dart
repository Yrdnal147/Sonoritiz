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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<LibraryUiCubit>().setActiveTab(_tabController.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LibraryUiCubit>().setActiveTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _searchHintForTab(String tabId) {
    switch (tabId) {
      case 'downloads':
        return "Titre ou artiste téléchargé...";
      case 'local':
        return "Titre ou artiste local...";
      case 'favorites':
        return "Rechercher un titre ou artiste favori...";
      case 'playlists':
        return "Rechercher une playlist...";
      case 'history':
        return "Rechercher dans l'historique...";
      default:
        return "Rechercher dans la bibliothèque...";
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
          prev.isSearchActive != curr.isSearchActive,
      listener: (context, uiState) {
        if (!uiState.isSearchActive || uiState.searchQuery.isEmpty) {
          if (_searchController.text.isNotEmpty && uiState.searchQuery.isEmpty) {
            _searchController.clear();
          }
        }
      },
      builder: (context, uiState) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SonoritizDynamicBackground(
            child: SafeArea(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      pinned: true,
                      floating: true,
                      centerTitle: false,
                      toolbarHeight: 68,
                      titleSpacing: AppDimensions.spacingMd,
                      title: uiState.isSearchActive
                          ? TextField(
                              controller: _searchController,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              style: textTheme.titleMedium
                                  ?.copyWith(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: _searchHintForTab(uiState.activeTabId),
                                hintStyle: textTheme.titleMedium
                                    ?.copyWith(color: Colors.white54),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                              ),
                              onChanged: (value) {
                                context
                                    .read<LibraryUiCubit>()
                                    .updateSearchQuery(value);
                              },
                            )
                          : const SonoritizPageTitle(title: "Ma Bibliothèque"),
                      actions: [
                        IconButton(
                          icon: Icon(
                            uiState.isSearchActive
                                ? Icons.close_rounded
                                : Icons.search_rounded,
                            color: Colors.white,
                          ),
                          tooltip: uiState.isSearchActive
                              ? "Fermer la recherche"
                              : "Rechercher",
                          onPressed: () {
                            if (uiState.isSearchActive) {
                              _searchController.clear();
                              context.read<LibraryUiCubit>().closeSearch();
                            } else {
                              context.read<LibraryUiCubit>().toggleSearch();
                            }
                          },
                        ),
                        if (!uiState.isSearchActive) ...[
                          IconButton(
                            icon: Icon(
                              uiState.currentSortMode == SortMode.alpha
                                  ? Icons.sort_by_alpha_rounded
                                  : Icons.access_time_rounded,
                              color: Colors.white,
                            ),
                            tooltip: "Changer le tri",
                            onPressed: () =>
                                context.read<LibraryUiCubit>().toggleSortMode(),
                          ),
                          PopupMenuButton<ViewMode>(
                            icon: const Icon(Icons.grid_view_rounded,
                                color: Colors.white),
                            color: colorScheme.surface,
                            tooltip: "Mode d'affichage",
                            onSelected: (mode) => context
                                .read<LibraryUiCubit>()
                                .setViewMode(mode),
                            itemBuilder: (context) => [
                              _buildViewMenuItem(context, ViewMode.list,
                                  Icons.view_list_rounded, "Liste", uiState.currentViewMode),
                              _buildViewMenuItem(context, ViewMode.listCompact,
                                  Icons.density_small_rounded, "Liste Compacte", uiState.currentViewMode),
                              _buildViewMenuItem(context, ViewMode.gridSmall,
                                  Icons.grid_on_rounded, "Petite Grille", uiState.currentViewMode),
                              _buildViewMenuItem(context, ViewMode.gridMedium,
                                  Icons.grid_view_rounded, "Grille", uiState.currentViewMode),
                              _buildViewMenuItem(context, ViewMode.gridLarge,
                                  Icons.crop_square_rounded, "Grande Grille", uiState.currentViewMode),
                              _buildViewMenuItem(context, ViewMode.cards,
                                  Icons.view_carousel_rounded, "Cartes", uiState.currentViewMode),
                            ],
                          ),
                        ],
                      ],
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(54),
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(bottom: 6),
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            indicator: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: AppColors.primary.withValues(alpha: 0.16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.48),
                                width: 1.1,
                              ),
                            ),
                            indicatorPadding:
                                const EdgeInsets.symmetric(vertical: 6),
                            labelColor: Colors.white,
                            unselectedLabelColor:
                                Colors.white.withValues(alpha: 0.55),
                            labelStyle: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            unselectedLabelStyle: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.1,
                            ),
                            dividerColor: Colors.transparent,
                            splashBorderRadius: BorderRadius.circular(24),
                            tabs: const [
                              Tab(
                                  child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 14),
                                      child: Text("Favoris"))),
                              Tab(
                                  child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 14),
                                      child: Text("Playlists"))),
                              Tab(
                                  child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 14),
                                      child: Text("Historique"))),
                              Tab(
                                  child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 14),
                                      child: Text("Téléchargements"))),
                              Tab(
                                  child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 14),
                                      child: Text("Sons internes"))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ];
                },
                body: BlocBuilder<LibraryCubit, LibraryState>(
                  builder: (context, state) {
                    if (state is LibraryLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (state is LibraryError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                size: AppDimensions.iconXxl,
                                color: colorScheme.error),
                            const SizedBox(height: AppDimensions.spacingMd),
                            Text(state.message, style: textTheme.bodyLarge),
                            const SizedBox(height: AppDimensions.spacingLg),
                            ElevatedButton(
                              onPressed: () =>
                                  context.read<LibraryCubit>().loadLibraryData(),
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
                              .where((p) => LibraryUiCubit.normalizeForSearch(
                                      p.name)
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
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            size: AppDimensions.iconSm,
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Text(
            title,
            style: TextStyle(
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
