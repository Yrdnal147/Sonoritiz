import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/home/data/repositories/catalog_repository.dart';
import '../../features/library/data/repositories/library_repository.dart';
import '../../features/library/presentation/cubit/library_cubit.dart';
import '../../features/offline/presentation/cubit/download_cubit.dart';
import '../../features/player/data/models/track_model.dart';
import '../../features/player/presentation/cubit/player_cubit.dart';
import '../storage/storage_service.dart';
import '../theme/app_colors.dart';
import 'artist_name_display.dart';
import 'playlist_cover_mosaic.dart';
import 'sonoritiz_artwork.dart';

/// Menu contextuel unifié ADN Sonoritiz pour les Albums, Playlists et Collections
/// (Appui long sur une pochette d'album/playlist ou clic sur •••).
/// Intègre systématiquement « Lire ensuite », « Ajouter à la file d'attente »,
/// « Télécharger l'album » et les actions propres au contenu.
class CollectionContextMenu {
  static Future<void> showForAlbum(
    BuildContext context, {
    required String albumId,
    required String title,
    required String artistName,
    required String coverUrl,
    String year = '',
    List<TrackModel>? preloadedTracks,
    bool isEditorialPlaylist = false,
  }) {
    HapticFeedback.mediumImpact();
    final playerCubit = context.read<PlayerCubit>();
    LibraryCubit? libraryCubit;
    DownloadCubit? downloadCubit;
    try {
      libraryCubit = context.read<LibraryCubit>();
    } catch (_) {}
    try {
      downloadCubit = context.read<DownloadCubit>();
    } catch (_) {}

    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        Widget sheet = _AlbumOrCollectionSheet(
          albumId: albumId,
          title: title,
          artistName: artistName,
          coverUrl: coverUrl,
          year: year,
          preloadedTracks: preloadedTracks,
          isEditorialPlaylist: isEditorialPlaylist,
          playerCubit: playerCubit,
          libraryCubit: libraryCubit,
          downloadCubit: downloadCubit,
        );
        return BlocProvider<PlayerCubit>.value(
          value: playerCubit,
          child: sheet,
        );
      },
    );
  }

  static Future<void> showForPlaylist(
    BuildContext context, {
    required PlaylistModel playlist,
    VoidCallback? onEdit,
    VoidCallback? onTogglePin,
    VoidCallback? onDelete,
  }) {
    HapticFeedback.mediumImpact();
    final playerCubit = context.read<PlayerCubit>();
    DownloadCubit? downloadCubit;
    try {
      downloadCubit = context.read<DownloadCubit>();
    } catch (_) {}

    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final count = playlist.tracks.isNotEmpty
            ? playlist.tracks.length
            : playlist.tracksCount;
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF121217),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Row(
                  children: [
                    PlaylistCoverMosaic(
                      playlist: playlist,
                      size: 56,
                      height: 56,
                      borderRadius: 12,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "$count ${count > 1 ? 'titres' : 'titre'}",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.60),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                const SizedBox(height: 6),
                if (playlist.tracks.isNotEmpty) ...[
                  _MenuActionTile(
                    icon: Icons.play_arrow_rounded,
                    iconColor: AppColors.primary,
                    label: "Lire la playlist",
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      playerCubit.playTrack(
                        playlist.tracks.first,
                        queue: playlist.tracks,
                        source: "la playlist ${playlist.name}",
                      );
                    },
                  ),
                  _MenuActionTile(
                    icon: Icons.playlist_play_rounded,
                    iconColor: AppColors.primary,
                    label: "Lire ensuite",
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      playerCubit.playTrackListNext(
                        playlist.tracks,
                        source: "la playlist ${playlist.name}",
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "« ${playlist.name} » sera lue ensuite",
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  _MenuActionTile(
                    icon: Icons.queue_music_rounded,
                    label: "Ajouter à la file d'attente",
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      playerCubit.addTrackListToQueue(
                        playlist.tracks,
                        source: "la playlist ${playlist.name}",
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "« ${playlist.name} » ajoutée à la file d'attente",
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  if (downloadCubit != null)
                    _MenuActionTile(
                      icon: Icons.download_rounded,
                      label: "Télécharger la playlist",
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        for (final t in playlist.tracks) {
                          downloadCubit!.downloadTrack(t);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Téléchargement de « ${playlist.name} » lancé",
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                ],
                if (onEdit != null)
                  _MenuActionTile(
                    icon: Icons.edit_outlined,
                    label: "Modifier la playlist",
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onEdit();
                    },
                  ),
                if (onTogglePin != null)
                  _MenuActionTile(
                    icon: playlist.isPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    iconColor:
                        playlist.isPinned ? AppColors.primary : Colors.white,
                    label: playlist.isPinned
                        ? "Désépingler"
                        : "Épingler en haut",
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onTogglePin();
                    },
                  ),
                _MenuActionTile(
                  icon: Icons.share_rounded,
                  label: "Partager",
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Share.share(
                      "Découvre la playlist « ${playlist.name} » sur Sonoritiz !",
                    );
                  },
                ),
                if (onDelete != null)
                  _MenuActionTile(
                    icon: Icons.delete_outline_rounded,
                    iconColor: AppColors.error,
                    textColor: AppColors.error,
                    label: "Supprimer la playlist",
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onDelete();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AlbumOrCollectionSheet extends StatefulWidget {
  final String albumId;
  final String title;
  final String artistName;
  final String coverUrl;
  final String year;
  final List<TrackModel>? preloadedTracks;
  final bool isEditorialPlaylist;
  final PlayerCubit playerCubit;
  final LibraryCubit? libraryCubit;
  final DownloadCubit? downloadCubit;

  const _AlbumOrCollectionSheet({
    required this.albumId,
    required this.title,
    required this.artistName,
    required this.coverUrl,
    required this.year,
    required this.preloadedTracks,
    required this.isEditorialPlaylist,
    required this.playerCubit,
    this.libraryCubit,
    this.downloadCubit,
  });

  @override
  State<_AlbumOrCollectionSheet> createState() =>
      _AlbumOrCollectionSheetState();
}

class _AlbumOrCollectionSheetState extends State<_AlbumOrCollectionSheet> {
  List<TrackModel> _tracks = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedTracks != null && widget.preloadedTracks!.isNotEmpty) {
      _tracks = widget.preloadedTracks!;
    } else {
      _fetchTracksIfNeeded();
    }
  }

  Future<List<TrackModel>> _fetchTracksIfNeeded() async {
    if (_tracks.isNotEmpty) return _tracks;
    if (mounted) setState(() => _loading = true);
    try {
      final repo = CatalogRepository();
      List<TrackModel> fetched = const [];
      final int? numId = int.tryParse(widget.albumId.trim());
      if (widget.isEditorialPlaylist && widget.albumId.trim().isNotEmpty) {
        fetched = await repo.getPlaylistTracksDeezer(
          widget.albumId.trim(),
          limit: 50,
        );
      } else if (numId != null && numId > 0) {
        fetched = await repo.getAlbumTracksDeezer(
          numId,
          widget.coverUrl,
          widget.artistName,
          albumTitle: widget.title,
        );
      }
      if (mounted) {
        setState(() {
          _tracks = fetched;
          _loading = false;
        });
      }
      return fetched;
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLiked = !widget.isEditorialPlaylist &&
        (widget.libraryCubit?.isAlbumFavorite(
              albumId: widget.albumId,
              title: widget.title,
              artistName: widget.artistName,
            ) ??
            false);

    final bool isDownloaded = !widget.isEditorialPlaylist &&
        StorageService().isAlbumRegisteredDownloaded(
          id: widget.albumId,
          title: widget.title,
          artistName: widget.artistName,
        );

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF121217),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Row(
              children: [
                SonoritizArtwork(
                  imageUrl: widget.coverUrl,
                  width: 58,
                  height: 58,
                  borderRadius: 12,
                  cacheMaxDimension: 180,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      ArtistNameDisplay(
                        artistName: widget.artistName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 6),
            _MenuActionTile(
              icon: Icons.play_arrow_rounded,
              iconColor: AppColors.primary,
              label: widget.isEditorialPlaylist
                  ? "Lire la sélection"
                  : "Lire l'album",
              onTap: () async {
                final tracks = await _fetchTracksIfNeeded();
                if (!context.mounted) return;
                Navigator.pop(context);
                if (tracks.isNotEmpty) {
                  widget.playerCubit.playTrack(
                    tracks.first,
                    queue: tracks,
                    source: widget.title,
                  );
                }
              },
            ),
            _MenuActionTile(
              icon: Icons.playlist_play_rounded,
              iconColor: AppColors.primary,
              label: "Lire ensuite",
              onTap: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                final tracks = await _fetchTracksIfNeeded();
                if (!context.mounted) return;
                Navigator.pop(context);
                if (tracks.isNotEmpty) {
                  widget.playerCubit.playTrackListNext(
                    tracks,
                    source: widget.title,
                  );
                  messenger?.showSnackBar(
                    SnackBar(
                      content: Text("« ${widget.title} » sera lu ensuite"),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            _MenuActionTile(
              icon: Icons.queue_music_rounded,
              label: "Ajouter à la file d'attente",
              onTap: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                final tracks = await _fetchTracksIfNeeded();
                if (!context.mounted) return;
                Navigator.pop(context);
                if (tracks.isNotEmpty) {
                  widget.playerCubit.addTrackListToQueue(
                    tracks,
                    source: widget.title,
                  );
                  messenger?.showSnackBar(
                    SnackBar(
                      content: Text(
                        "« ${widget.title} » ajouté à la file d'attente",
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            if (!widget.isEditorialPlaylist && widget.libraryCubit != null)
              _MenuActionTile(
                icon: isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                iconColor: isLiked ? AppColors.primary : Colors.white,
                label: isLiked
                    ? "Retirer des albums favoris"
                    : "Ajouter aux albums favoris",
                onTap: () async {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  final tracks = await _fetchTracksIfNeeded();
                  if (!context.mounted) return;
                  await widget.libraryCubit!.toggleFavoriteAlbum(
                    albumId: widget.albumId,
                    title: widget.title,
                    artistName: widget.artistName,
                    coverUrl: widget.coverUrl,
                    year: widget.year,
                    albumTracks: tracks,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  messenger?.showSnackBar(
                    SnackBar(
                      content: Text(
                        isLiked
                            ? "Album retiré des favoris"
                            : "Album ajouté aux favoris",
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            if (!widget.isEditorialPlaylist && widget.downloadCubit != null)
              _MenuActionTile(
                icon: isDownloaded
                    ? Icons.delete_outline_rounded
                    : Icons.download_rounded,
                iconColor: isDownloaded ? AppColors.error : Colors.white,
                textColor: isDownloaded ? AppColors.error : Colors.white,
                label: isDownloaded
                    ? "Supprimer l'album téléchargé"
                    : "Télécharger l'album",
                onTap: () async {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  final tracks = await _fetchTracksIfNeeded();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (isDownloaded) {
                    await widget.downloadCubit!.removeAlbumDownload(
                      albumId: widget.albumId,
                      title: widget.title,
                      artistName: widget.artistName,
                      trackIds: tracks.map((t) => t.id).toList(),
                    );
                    messenger?.showSnackBar(
                      SnackBar(
                        content: Text(
                          "Album « ${widget.title} » supprimé des téléchargements",
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else if (tracks.isNotEmpty) {
                    await widget.downloadCubit!.downloadAlbum(
                      albumId: widget.albumId,
                      title: widget.title,
                      artistName: widget.artistName,
                      coverUrl: widget.coverUrl,
                      tracks: tracks,
                    );
                    messenger?.showSnackBar(
                      SnackBar(
                        content: Text(
                          "Téléchargement de l'album « ${widget.title} » lancé",
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            _MenuActionTile(
              icon: Icons.share_rounded,
              label: "Partager",
              onTap: () {
                Navigator.pop(context);
                Share.share(
                  "Découvre « ${widget.title} » de ${widget.artistName} sur Sonoritiz !",
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final String label;
  final VoidCallback onTap;

  const _MenuActionTile({
    required this.icon,
    this.iconColor = Colors.white,
    this.textColor = Colors.white,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 23),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
