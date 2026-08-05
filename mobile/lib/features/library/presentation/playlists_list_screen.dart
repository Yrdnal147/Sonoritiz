import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../data/repositories/library_repository.dart';
import 'cubit/library_cubit.dart';
import 'playlist_detail_screen.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../../core/utils/responsive_utils.dart';

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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Supprimer ?", style: TextStyle(color: Colors.white)),
        content: Text("Veux-tu vraiment supprimer la playlist '${playlist.name}' ?", style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<LibraryCubit>().deletePlaylist(playlist.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showCreatePlaylistDialog(context),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
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
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveUtils.getGridCrossAxisCount(context),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.85,
              ),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<PlayerCubit>(),
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
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                              child: playlist.coverUrl.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: playlist.coverUrl, width: double.infinity, fit: BoxFit.cover)
                                  : Container(
                                      color: AppColors.surfaceLight,
                                      child: const Center(child: Icon(Icons.playlist_play, size: 48, color: Colors.white54)),
                                    ),
                            ),
                            if (playlist.isPinned)
                              const Positioned(
                                top: 8,
                                right: 8,
                                child: Icon(Icons.push_pin, color: AppColors.primary, size: 20),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text("${playlist.tracksCount} morceaux", style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
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
}
