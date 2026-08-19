import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/playlist_cover_mosaic.dart';
import '../../../core/widgets/sonoritiz_icon_button.dart';
import '../data/repositories/library_repository.dart';
import 'cubit/library_cubit.dart';
import 'playlist_detail_screen.dart';
import 'cubit/library_ui_cubit.dart';

class PlaylistsListScreen extends StatelessWidget {
  final List<PlaylistModel> playlists;

  const PlaylistsListScreen({Key? key, required this.playlists}) : super(key: key);

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    String? selectedImagePath;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: colorScheme.surface,
            title: const Text("Nouvelle Playlist"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      setState(() {
                        selectedImagePath = pickedFile.path;
                      });
                    }
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      image: selectedImagePath != null 
                          ? DecorationImage(image: FileImage(File(selectedImagePath!)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: selectedImagePath == null 
                        ? Icon(Icons.add_a_photo_rounded, color: colorScheme.onSurfaceVariant, size: AppDimensions.iconXl)
                        : null,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: "Nom de la playlist"),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text("Annuler", style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    context.read<LibraryCubit>().createPlaylist(
                      controller.text.trim(),
                      coverUrl: selectedImagePath != null ? 'http://local.image/$selectedImagePath' : ''
                    );
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text("Créer"),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showPlaylistContextMenu(BuildContext context, PlaylistModel playlist) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: AppDimensions.spacingMd),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
              ),
              Text(playlist.name, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text("${playlist.tracksCount} titres", style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppDimensions.spacingSm),
              Divider(color: colorScheme.outline.withOpacity(0.2)),
              ListTile(
                leading: Icon(Icons.edit_rounded, color: colorScheme.onSurface),
                title: const Text("Modifier"),
                onTap: () => Navigator.pop(bottomSheetContext),
              ),
              ListTile(
                leading: Icon(playlist.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, color: colorScheme.onSurface),
                title: Text(playlist.isPinned ? "Désépingler" : "Épingler"),
                onTap: () {
                  context.read<LibraryCubit>().togglePinPlaylist(playlist.id, playlist.isPinned);
                  Navigator.pop(bottomSheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                title: const Text("Supprimer", style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _confirmDelete(context, playlist);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, PlaylistModel playlist) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: const Text("Supprimer"),
        content: Text("Veux-tu vraiment supprimer la playlist '${playlist.name}' ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Annuler", style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePlaylistDialog(context),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Nouvelle"),
      ),
      body: playlists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music_rounded, size: 64, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Text("Crée ta première playlist", style: textTheme.titleLarge),
                  const SizedBox(height: AppDimensions.spacingSm),
                  ElevatedButton(
                    onPressed: () => _showCreatePlaylistDialog(context),
                    child: const Text("Créer une playlist"),
                  ),
                ],
              ),
            )
          : BlocBuilder<LibraryUiCubit, LibraryUiState>(
              builder: (context, uiState) {
                List<PlaylistModel> sortedPlaylists = List.from(playlists);
                final currentSortMode = uiState.getSortModeFor('playlists');
                
                if (currentSortMode == SortMode.alpha) {
                  sortedPlaylists.sort((a, b) {
                    if (a.isPinned && !b.isPinned) return -1;
                    if (!a.isPinned && b.isPinned) return 1;
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  });
                } else {
                  sortedPlaylists.sort((a, b) {
                    if (a.isPinned && !b.isPinned) return -1;
                    if (!a.isPinned && b.isPinned) return 1;
                    return b.id.compareTo(a.id);
                  });
                }

                final currentViewMode = uiState.getViewModeFor('playlists');
                if (currentViewMode == ViewMode.list) {
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
                switch (currentViewMode) {
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
                      padding: const EdgeInsets.all(AppDimensions.spacingMd),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: AppDimensions.spacingMd,
                          mainAxisSpacing: AppDimensions.spacingMd,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildGridItem(context, sortedPlaylists[index], currentViewMode),
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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: "Ouvrir la playlist ${playlist.name}",
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd, vertical: AppDimensions.spacingXs),
        leading: PlaylistCoverMosaic(
          playlist: playlist,
          size: 52,
          borderRadius: AppDimensions.radiusSm,
        ),
        title: Row(
          children: [
            if (playlist.isPinned) Icon(Icons.push_pin_rounded, color: colorScheme.primary, size: AppDimensions.iconSm),
            if (playlist.isPinned) const SizedBox(width: AppDimensions.spacingXs),
            Expanded(child: Text(playlist.name, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
        subtitle: Text("${playlist.tracksCount} titres", style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        trailing: SonoritizIconButton(
          icon: Icons.more_horiz_rounded,
          tooltip: "Options",
          color: colorScheme.onSurfaceVariant,
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
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, PlaylistModel playlist, ViewMode mode) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: "Ouvrir la playlist ${playlist.name}",
      child: GestureDetector(
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
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PlaylistCoverMosaic(
                        playlist: playlist,
                        size: double.infinity,
                        borderRadius: 0,
                      ),
                      if (playlist.isPinned)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.push_pin_rounded, color: colorScheme.primary, size: 16),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${playlist.tracksCount} titres",
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
