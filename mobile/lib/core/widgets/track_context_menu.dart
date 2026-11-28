import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart' as import_go_router;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../features/player/data/models/track_model.dart';
import '../../../features/player/presentation/cubit/player_cubit.dart';
import '../../features/library/presentation/cubit/library_cubit.dart';
import '../../features/library/presentation/cubit/library_state.dart';
import 'artist_name_display.dart';
import '../../../features/offline/presentation/cubit/download_cubit.dart';
import '../../../features/home/data/repositories/catalog_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/share_utils.dart';

class TrackContextMenu extends StatelessWidget {
  final TrackModel track;
  final int? playlistId;

  const TrackContextMenu({Key? key, required this.track, this.playlistId}) : super(key: key);

  static void show(BuildContext context, TrackModel track, {int? playlistId}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TrackContextMenu(track: track, playlistId: playlistId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicateur de glissement supérieur (Drag Handle)
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // En-tête avec la pochette et le titre
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: track.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: track.coverUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 64,
                          height: 64,
                          color: AppColors.surface,
                          child: const Icon(Icons.music_note, color: Colors.white54),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      ArtistNameDisplay(
                        artistName: track.artistName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),

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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isFavorite ? "Retiré des favoris" : "Ajouté aux favoris"),
                        backgroundColor: AppColors.surface,
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),

            // Action: Playlists
            _buildMenuOption(
              icon: Icons.playlist_add_rounded,
              title: "Ajouter à une playlist",
              onTap: () {
                Navigator.pop(context);
                _showPlaylistsSelection(context);
              },
            ),
            const SizedBox(height: 12),

            // Action: Lire ensuite (Son ou Podcast suivant immédiat)
            _buildMenuOption(
              icon: Icons.playlist_play_rounded,
              iconColor: AppColors.primary,
              title: "Lire ensuite",
              onTap: () {
                context.read<PlayerCubit>().playTrackNext(track);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("« ${track.title} » sera lu ensuite"),
                    backgroundColor: AppColors.surface,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            if (track.isPodcastOrBook) ...[
              _buildMenuOption(
                icon: Icons.videocam_rounded,
                iconColor: AppColors.primary,
                title: "Voir la vidéo du podcast",
                onTap: () {
                  final router = import_go_router.GoRouter.of(context);
                  Navigator.pop(context);
                  router.push(
                    '/podcast_player',
                    extra: <String, dynamic>{
                      'track': track,
                      'initialVideoMode': true,
                      'initialPositionSeconds': 0,
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
            ],

            // Action: File d'attente
            _buildMenuOption(
              icon: Icons.queue_music_rounded,
              title: "Ajouter à la file d'attente",
              onTap: () {
                context.read<PlayerCubit>().addToQueue(track);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("« ${track.title} » ajouté à la file d'attente"),
                    backgroundColor: AppColors.surface,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Action: Lancer la radio du titre
            _buildMenuOption(
              icon: Icons.sensors_rounded,
              iconColor: AppColors.primary,
              title: "Lancer la radio du titre",
              onTap: () {
                context.read<PlayerCubit>().startTrackRadio(track);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Radio lancée autour de « ${track.title} »"),
                    backgroundColor: AppColors.surface,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Action: Voir l'album
            _buildMenuOption(
              icon: Icons.album_outlined,
              title: "Voir l'album",
              onTap: () async {
                final router = import_go_router.GoRouter.of(context);
                Navigator.pop(context);
                int albumId = 0;
                String albumTitle = track.albumName.trim();
                try {
                  final repo = CatalogRepository();
                  final cleanArtist = track.artistName
                      .split(RegExp(r',|&|feat\.|ft\.', caseSensitive: false))
                      .first
                      .trim();
                  final albums = await repo.searchAlbums(
                    albumTitle.isNotEmpty &&
                            albumTitle != 'YouTube Audio' &&
                            albumTitle != 'Unknown Album'
                        ? '$cleanArtist $albumTitle'
                        : '$cleanArtist ${track.title}',
                    limit: 4,
                  );
                  if (albums.isNotEmpty) {
                    albumId =
                        int.tryParse('${albums.first['id'] ?? 0}') ?? 0;
                    albumTitle =
                        (albums.first['title'] ?? albumTitle).toString();
                  }
                } catch (_) {}

                if (albumId > 0) {
                  router.push('/album', extra: {
                    'id': albumId,
                    'title': albumTitle,
                    'artistName': track.artistName,
                    'coverUrl': track.coverUrl,
                  });
                } else {
                  router.push('/collection', extra: {
                    'title':
                        albumTitle.isNotEmpty ? albumTitle : track.title,
                    'badgeLabel': 'ALBUM',
                    'subtitle': track.artistName,
                    'coverUrl': track.coverUrl,
                    'tracks': [track],
                    'playbackSource':
                        albumTitle.isNotEmpty ? albumTitle : track.title,
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            
            if (playlistId != null) ...[
              _buildMenuOption(
                icon: Icons.playlist_remove_rounded,
                iconColor: AppColors.error,
                title: "Retirer de la playlist",
                onTap: () {
                  context.read<LibraryCubit>().removeTrackFromPlaylist(playlistId!, track.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Retiré de la playlist"),
                      backgroundColor: AppColors.surface,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],

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
                  icon: isDownloaded
                      ? Icons.delete_outline_rounded
                      : (isDownloading
                          ? Icons.downloading_rounded
                          : Icons.download_rounded),
                  iconColor: isDownloaded ? AppColors.error : Colors.white,
                  title: isDownloaded
                      ? "Supprimer le téléchargement"
                      : (isDownloading
                          ? "Téléchargement en cours..."
                          : "Télécharger"),
                  onTap: () {
                    if (isDownloaded) {
                      context.read<DownloadCubit>().removeDownload(track.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Téléchargement supprimé"),
                          backgroundColor: AppColors.surface,
                        ),
                      );
                    } else if (!isDownloading) {
                      context.read<DownloadCubit>().downloadTrack(track);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Téléchargement démarré"),
                          backgroundColor: AppColors.surface,
                        ),
                      );
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            
            // Action: Partager
            _buildMenuOption(
              icon: Icons.share_rounded,
              title: "Partager",
              onTap: () {
                final rootCtx =
                    Navigator.of(context, rootNavigator: true).context;
                Navigator.pop(context);
                ShareUtils.shareTrack(track, context: rootCtx);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    Color iconColor = Colors.white,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: iconColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistsSelection(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      useRootNavigator: true,
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
                  const Text(
                    "Choisir une playlist",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  BlocBuilder<LibraryCubit, LibraryState>(
                    builder: (context, state) {
                      if (state is LibraryLoaded) {
                        final playlists = state.playlists;
                        if (playlists.isEmpty) {
                          return const Text(
                            "Aucune playlist disponible.",
                            style: TextStyle(color: AppColors.textSecondary),
                          );
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
                                  ScaffoldMessenger.of(parentContext).showSnackBar(
                                    SnackBar(
                                      content: Text("Ajouté à ${playlist.name}"),
                                      backgroundColor: AppColors.surface,
                                    ),
                                  );
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
