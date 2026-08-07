import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../features/player/data/models/track_model.dart';
import '../../../features/library/presentation/cubit/library_cubit.dart';
import '../../../features/library/presentation/cubit/library_state.dart';
import '../../../features/offline/presentation/cubit/download_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/share_utils.dart';

class TrackContextMenu extends StatelessWidget {
  final TrackModel track;

  const TrackContextMenu({Key? key, required this.track}) : super(key: key);

  static void show(BuildContext context, TrackModel track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TrackContextMenu(track: track),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête avec la pochette et le titre
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: track.coverUrl.isNotEmpty
                    ? CachedNetworkImage(imageUrl: track.coverUrl, width: 64, height: 64, fit: BoxFit.cover)
                    : Container(width: 64, height: 64, color: AppColors.surface, child: const Icon(Icons.music_note, color: Colors.white54)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(track.artistName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),

          // Action: Favoris
          BlocBuilder<LibraryCubit, LibraryState>(
            builder: (context, state) {
              final isFavorite = context.read<LibraryCubit>().isFavorite(track.id);
              return _buildMenuOption(
                icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                iconColor: isFavorite ? AppColors.primary : Colors.white,
                title: isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                onTap: () {
                  if (isFavorite) {
                    context.read<LibraryCubit>().removeFavorite(track.id);
                  } else {
                    context.read<LibraryCubit>().addFavorite(track);
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFavorite ? "Retiré des favoris" : "Ajouté aux favoris"), backgroundColor: AppColors.surface));
                },
              );
            },
          ),
          const SizedBox(height: 16),

          // Action: Playlists
          _buildMenuOption(
            icon: Icons.playlist_add_rounded,
            title: "Ajouter à une playlist",
            onTap: () {
              Navigator.pop(context);
              _showPlaylistsSelection(context);
            },
          ),
          const SizedBox(height: 16),

          // Action: Téléchargement
          BlocBuilder<DownloadCubit, DownloadState>(
            builder: (context, state) {
              bool isDownloaded = false;
              bool isDownloading = false;
              if (state is DownloadStateData) {
                isDownloaded = state.downloadedIds.contains(track.id);
                isDownloading = state.downloadingProgress.containsKey(track.id);
              }

              return _buildMenuOption(
                icon: isDownloaded ? Icons.delete_outline_rounded : (isDownloading ? Icons.downloading_rounded : Icons.download_rounded),
                iconColor: isDownloaded ? AppColors.error : Colors.white,
                title: isDownloaded ? "Supprimer le téléchargement" : (isDownloading ? "Téléchargement en cours..." : "Télécharger"),
                onTap: () {
                  if (isDownloaded) {
                    context.read<DownloadCubit>().removeDownload(track.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Téléchargement supprimé"), backgroundColor: AppColors.surface));
                  } else if (!isDownloading) {
                    context.read<DownloadCubit>().downloadTrack(track);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Téléchargement démarré"), backgroundColor: AppColors.surface));
                  }
                },
              );
            },
          ),
          const SizedBox(height: 16),
          
          // Action: Partager
          _buildMenuOption(
            icon: Icons.share_rounded,
            title: "Partager",
            onTap: () {
              Navigator.pop(context);
              ShareUtils.shareTrack(track);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMenuOption({required IconData icon, Color iconColor = Colors.white, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(color: iconColor, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showPlaylistsSelection(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (context) {
        return BlocProvider.value(
          value: parentContext.read<LibraryCubit>(),
          child: Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Choisir une playlist", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  BlocBuilder<LibraryCubit, LibraryState>(
                    builder: (context, state) {
                      if (state is LibraryLoaded) {
                        final playlists = state.playlists;
                        if (playlists.isEmpty) {
                          return const Text("Aucune playlist disponible.", style: TextStyle(color: AppColors.textSecondary));
                        }
                        return Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: playlists.length,
                            itemBuilder: (context, index) {
                              final playlist = playlists[index];
                              return ListTile(
                                leading: const Icon(Icons.queue_music, color: AppColors.primary),
                                title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
                                onTap: () {
                                  context.read<LibraryCubit>().addTrackToPlaylist(playlist.id, track);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(content: Text("Ajouté à ${playlist.name}"), backgroundColor: AppColors.surface));
                                },
                              );
                            },
                          ),
                        );
                      }
                      return const CircularProgressIndicator();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Annuler", style: TextStyle(color: AppColors.textSecondary)),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
