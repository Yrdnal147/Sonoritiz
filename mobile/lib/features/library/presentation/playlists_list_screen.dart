import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../data/repositories/library_repository.dart';
import 'cubit/library_cubit.dart';
import 'playlist_detail_screen.dart';
import '../../../core/utils/responsive_utils.dart';
import 'cubit/library_ui_cubit.dart';

class PlaylistsListScreen extends StatelessWidget {
  final List<PlaylistModel> playlists;

  const PlaylistsListScreen({Key? key, required this.playlists}) : super(key: key);

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Nouvelle Playlist", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Nom de la playlist"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Annuler", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<LibraryCubit>().createPlaylist(controller.text.trim());
                Navigator.pop(dialogContext);
              }
            },
            child: const Text("Créer"),
          ),
        ],
      ),
    );
  }

  void _showPlaylistContextMenu(BuildContext context, PlaylistModel playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(playlist.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text("${playlist.tracksCount} titres", style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 8),
              const Divider(color: AppColors.surfaceLight),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text("Modifier", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  // Modifier logiq later
                },
              ),
              ListTile(
                leading: Icon(playlist.isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: Colors.white),
                title: Text(playlist.isPinned ? "Désépingler" : "Épingler", style: const TextStyle(color: Colors.white)),
                onTap: () {
                  context.read<LibraryCubit>().togglePinPlaylist(playlist.id, playlist.isPinned);
                  Navigator.pop(bottomSheetContext);
                },
              ),
              const ListTile(
                leading: Icon(Icons.sensors, color: AppColors.textSecondary),
                title: Text("Connecter (Bientôt disponible)", style: TextStyle(color: AppColors.textSecondary)),
                onTap: null, // Désactivé
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: const Text("Supprimer", style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _confirmDelete(context, playlist);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, PlaylistModel playlist) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Supprimer", style: TextStyle(color: Colors.white)),
        content: Text("Veux-tu vraiment supprimer la playlist '${playlist.name}' ?", style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Annuler", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              context.read<LibraryCubit>().deletePlaylist(playlist.id);
              Navigator.pop(dialogContext);
            },
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Inherits from LibraryScreen
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePlaylistDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Nouvelle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: playlists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.queue_music, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text("Crée ta première playlist", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showCreatePlaylistDialog(context),
                    child: const Text("Créer une playlist"),
                  ),
                ],
              ),
            )
          : BlocBuilder<LibraryUiCubit, LibraryUiState>(
              builder: (context, uiState) {
                // Tri des playlists
                List<PlaylistModel> sortedPlaylists = List.from(playlists);
                if (uiState.sortMode == SortMode.alpha) {
                  sortedPlaylists.sort((a, b) {
                    if (a.isPinned && !b.isPinned) return -1;
                    if (!a.isPinned && b.isPinned) return 1;
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  });
                } else {
                  // "Recent" means keep original ID-based or DB order, but pinned first
                  sortedPlaylists.sort((a, b) {
                    if (a.isPinned && !b.isPinned) return -1;
                    if (!a.isPinned && b.isPinned) return 1;
                    return b.id.compareTo(a.id); // Assuming higher ID = newer
                  });
                }

                if (uiState.viewMode == ViewMode.list) {
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildListItem(context, sortedPlaylists[index]),
                          childCount: sortedPlaylists.length,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  );
                }

                int crossAxisCount;
                double childAspectRatio;
                switch (uiState.viewMode) {
                  case ViewMode.gridSmall:
                    crossAxisCount = 3;
                    childAspectRatio = 0.75;
                    break;
                  case ViewMode.gridLarge:
                    crossAxisCount = 1;
                    childAspectRatio = 1.0;
                    break;
                  case ViewMode.gridMedium:
                  default:
                    crossAxisCount = 2;
                    childAspectRatio = 0.8;
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildGridItem(context, sortedPlaylists[index], uiState.viewMode),
                          childCount: sortedPlaylists.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildListItem(BuildContext context, PlaylistModel playlist) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, Colors.deepPurple]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.queue_music, color: Colors.white),
      ),
      title: Row(
        children: [
          if (playlist.isPinned) const Icon(Icons.push_pin, color: AppColors.primary, size: 16),
          if (playlist.isPinned) const SizedBox(width: 4),
          Expanded(child: Text(playlist.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
      subtitle: Text("${playlist.tracksCount} titres", style: const TextStyle(color: AppColors.textSecondary)),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, color: Colors.white54),
        onPressed: () => _showPlaylistContextMenu(context, playlist),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<LibraryCubit>(),
              child: PlaylistDetailScreen(playlist: playlist),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridItem(BuildContext context, PlaylistModel playlist, ViewMode mode) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<LibraryCubit>(),
              child: PlaylistDetailScreen(playlist: playlist),
            ),
          ),
        );
      },
      onLongPress: () => _showPlaylistContextMenu(context, playlist),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.surface, AppColors.surfaceLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.queue_music, color: Colors.white24, size: 48),
                  ),
                  if (playlist.isPinned)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.background.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.push_pin, color: AppColors.primary, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: mode == ViewMode.gridSmall ? 12 : 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${playlist.tracksCount} titres",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: mode == ViewMode.gridSmall ? 10 : 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
