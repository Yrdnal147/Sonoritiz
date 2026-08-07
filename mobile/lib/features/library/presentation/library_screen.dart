import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/storage/storage_service.dart';
import 'cubit/library_cubit.dart';
import 'cubit/library_state.dart';
import 'cubit/library_ui_cubit.dart';
import 'favorites_screen.dart';
import 'playlists_list_screen.dart';
import 'history_screen.dart';
import 'downloads_screen.dart';
import 'local_audio_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const _LibraryScreenBody();
  }
}

class _LibraryScreenBody extends StatelessWidget {
  const _LibraryScreenBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: const Text(
            "Ma Bibliothèque",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 26,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
          actions: [
            BlocBuilder<LibraryUiCubit, LibraryUiState>(
              builder: (context, uiState) {
                return Row(
                  children: [
                    IconButton(
                      icon: Icon(uiState.sortMode == SortMode.alpha ? Icons.sort_by_alpha : Icons.access_time_rounded, color: Colors.white),
                      onPressed: () => context.read<LibraryUiCubit>().toggleSortMode(),
                      tooltip: "Changer le tri",
                    ),
                    PopupMenuButton<ViewMode>(
                      icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
                      color: AppColors.surface,
                      tooltip: "Mode d'affichage",
                      onSelected: (mode) => context.read<LibraryUiCubit>().setViewMode(mode),
                      itemBuilder: (context) => [
                        _buildViewMenuItem(ViewMode.list, Icons.view_list_rounded, "Liste", uiState.viewMode),
                        _buildViewMenuItem(ViewMode.gridSmall, Icons.grid_on_rounded, "Petite Grille", uiState.viewMode),
                        _buildViewMenuItem(ViewMode.gridMedium, Icons.grid_view_rounded, "Grille", uiState.viewMode),
                        _buildViewMenuItem(ViewMode.gridLarge, Icons.crop_square_rounded, "Grande", uiState.viewMode),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: Colors.white,
            isScrollable: true,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            unselectedLabelColor: AppColors.textSecondary,
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            dividerColor: Colors.white.withOpacity(0.05),
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
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            if (state is LibraryError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error.withOpacity(0.8)),
                    const SizedBox(height: 16),
                    Text(state.message, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () => context.read<LibraryCubit>().loadLibraryData(),
                      child: const Text("Réessayer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ).animate().fadeIn().scale();
            }

            if (state is LibraryLoaded) {
              return TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  FavoritesScreen(favorites: state.favorites),
                  PlaylistsListScreen(playlists: state.playlists),
                  HistoryScreen(history: state.history),
                  const DownloadsScreen(),
                  LocalAudioScreen(storageService: context.read<LibraryUiCubit>().storageService),
                ],
              );
            }

            return const SizedBox();
          },
        ),
      ),
    );
  }

  PopupMenuItem<ViewMode> _buildViewMenuItem(ViewMode mode, IconData icon, String title, ViewMode currentMode) {
    final isSelected = mode == currentMode;
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon, color: isSelected ? AppColors.primary : Colors.white70, size: 20),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(color: isSelected ? AppColors.primary : Colors.white)),
        ],
      ),
    );
  }
}
