import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

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
      context.read<LibraryUiCubit>().setActiveTab(_tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<LibraryUiCubit, LibraryUiState>(
      builder: (context, uiState) {
        return Scaffold(
          appBar: AppBar(
            title: uiState.isSearchActive
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: textTheme.titleMedium,
                    decoration: InputDecoration(
                      hintText: "Rechercher dans la bibliothèque...",
                      hintStyle: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (value) {
                      context.read<LibraryUiCubit>().updateSearchQuery(value);
                    },
                  )
                : Text(
                    "Ma Bibliothèque",
                    style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
            actions: [
              IconButton(
                icon: Icon(
                  uiState.isSearchActive ? Icons.close_rounded : Icons.search_rounded,
                ),
                tooltip: uiState.isSearchActive ? "Fermer la recherche" : "Rechercher",
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
                    uiState.currentSortMode == SortMode.alpha ? Icons.sort_by_alpha_rounded : Icons.access_time_rounded,
                  ),
                  tooltip: "Changer le tri",
                  onPressed: () => context.read<LibraryUiCubit>().toggleSortMode(),
                ),
                PopupMenuButton<ViewMode>(
                  icon: const Icon(Icons.grid_view_rounded),
                  color: colorScheme.surface,
                  tooltip: "Mode d'affichage",
                  onSelected: (mode) => context.read<LibraryUiCubit>().setViewMode(mode),
                  itemBuilder: (context) => [
                    _buildViewMenuItem(context, ViewMode.list, Icons.view_list_rounded, "Liste", uiState.currentViewMode),
                    _buildViewMenuItem(context, ViewMode.gridSmall, Icons.grid_on_rounded, "Petite Grille", uiState.currentViewMode),
                    _buildViewMenuItem(context, ViewMode.gridMedium, Icons.grid_view_rounded, "Grille", uiState.currentViewMode),
                    _buildViewMenuItem(context, ViewMode.gridLarge, Icons.crop_square_rounded, "Grande", uiState.currentViewMode),
                  ],
                ),
              ],
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: colorScheme.primary,
              indicatorWeight: 3,
              labelColor: colorScheme.onSurface,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              isScrollable: true,
              labelStyle: textTheme.titleSmall,
              unselectedLabelStyle: textTheme.titleSmall,
              dividerColor: colorScheme.outline.withOpacity(0.2),
              tabs: const [
                Tab(text: "Favoris"),
                Tab(text: "Playlists"),
                Tab(text: "Historique"),
                Tab(text: "Téléchargements"),
                Tab(text: "Sons internes"),
              ],
            ),
          ),
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
                      Icon(Icons.error_outline_rounded, size: AppDimensions.iconXxl, color: colorScheme.error),
                      const SizedBox(height: AppDimensions.spacingMd),
                      Text(state.message, style: textTheme.bodyLarge),
                      const SizedBox(height: AppDimensions.spacingLg),
                      ElevatedButton(
                        onPressed: () => context.read<LibraryCubit>().loadLibraryData(),
                        child: const Text("Réessayer"),
                      ),
                    ],
                  ),
                );
              }

              if (state is LibraryLoaded) {
                final query = uiState.searchQuery.toLowerCase().trim();

                final filteredFavorites = query.isEmpty
                    ? state.favorites
                    : state.favorites.where((t) =>
                        t.title.toLowerCase().contains(query) ||
                        t.artistName.toLowerCase().contains(query)).toList();

                final filteredPlaylists = query.isEmpty
                    ? state.playlists
                    : state.playlists.where((p) =>
                        p.name.toLowerCase().contains(query)).toList();

                final filteredHistory = query.isEmpty
                    ? state.history
                    : state.history.where((h) {
                        if (h.track != null) {
                          return h.track!.title.toLowerCase().contains(query) ||
                                 h.track!.artistName.toLowerCase().contains(query);
                        }
                        return h.trackId.toLowerCase().contains(query);
                      }).toList();

                return TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    FavoritesScreen(favorites: filteredFavorites),
                    PlaylistsListScreen(playlists: filteredPlaylists),
                    HistoryScreen(history: filteredHistory),
                    const DownloadsScreen(),
                    LocalAudioScreen(storageService: context.read<LibraryUiCubit>().storageService),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  PopupMenuItem<ViewMode> _buildViewMenuItem(BuildContext context, ViewMode mode, IconData icon, String title, ViewMode currentMode) {
    final isSelected = mode == currentMode;
    final colorScheme = Theme.of(context).colorScheme;
    
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurface, size: AppDimensions.iconSm),
          const SizedBox(width: AppDimensions.spacingMd),
          Text(title, style: TextStyle(color: isSelected ? colorScheme.primary : colorScheme.onSurface)),
        ],
      ),
    );
  }
}
