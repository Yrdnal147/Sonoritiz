import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/sonoritiz_artwork.dart';
import '../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../core/widgets/sonoritiz_fast_scrollbar.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../offline/data/models/offline_track_model.dart';
import '../../offline/presentation/cubit/download_cubit.dart';
import '../../../core/widgets/track_grid_view.dart';
import 'cubit/library_ui_cubit.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/data/models/track_model.dart';
import 'cubit/library_cubit.dart';
import 'cubit/library_state.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isSelectionMode = false;
  final Set<String> _selectedTrackIds = {};

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedTrackIds.clear();
    });
  }

  void _selectAll(List<OfflineTrackModel> tracks) {
    setState(() {
      _selectedTrackIds.addAll(tracks.map((e) => e.track.id));
    });
  }

  void _onSelectionChanged(String trackId, bool selected) {
    setState(() {
      if (selected) {
        _selectedTrackIds.add(trackId);
      } else {
        _selectedTrackIds.remove(trackId);
      }
    });
  }

  bool _matchesTrackQuery(TrackModel track, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    final title = LibraryUiCubit.normalizeForSearch(track.title);
    final artist = LibraryUiCubit.normalizeForSearch(track.artistName);
    final album = LibraryUiCubit.normalizeForSearch(track.albumName);
    return title.contains(normalizedQuery) ||
        artist.contains(normalizedQuery) ||
        album.contains(normalizedQuery);
  }

  void _showPlaylistsSelectionForMultiple(
      BuildContext parentContext, List<TrackModel> tracks) {
    final libraryState = parentContext.read<LibraryCubit>().state;
    final playlists =
        libraryState is LibraryLoaded ? libraryState.playlists : <dynamic>[];

    showDialog(
      context: parentContext,
      builder: (context) {
        return Dialog(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.playlist_add_rounded,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Ajouter ${tracks.length} titre${tracks.length > 1 ? 's' : ''}",
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                      "Aucune playlist disponible.\nCréez une playlist d'abord.",
                      textAlign: TextAlign.center),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15),
                          child: Icon(Icons.queue_music,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(playlist.name),
                        subtitle:
                            Text("${playlist.tracks?.length ?? 0} titres"),
                        onTap: () {
                          parentContext
                              .read<LibraryCubit>()
                              .addMultipleTracksToPlaylist(
                                  playlist.id, tracks);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                  "✅ ${tracks.length} titre${tracks.length > 1 ? 's' : ''} ajouté${tracks.length > 1 ? 's' : ''} à \"${playlist.name}\""),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          _toggleSelectionMode();
                        },
                      );
                    },
                  ),
                ),
              const Divider(height: 1),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Annuler"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count, {Widget? trailing}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 16, 12),
      child: Row(
        children: [
          Text(title,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: tt.labelSmall?.copyWith(
                  color: cs.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildDownloadingCard(BuildContext context, ActiveDownloadTask task) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cubit = context.read<DownloadCubit>();

    final isDownloading = task.status == DownloadStatus.downloading;
    final isPaused = task.status == DownloadStatus.paused;
    final isQueued = task.status == DownloadStatus.queued;
    final isFailed = task.status == DownloadStatus.failed;

    Color statusColor = cs.primary;
    String statusText = "${(task.progress * 100).toInt()}%";
    if (isPaused) {
      statusColor = const Color(0xFFFE9920);
      statusText = "En pause (${(task.progress * 100).toInt()}%)";
    } else if (isQueued) {
      statusColor = cs.onSurfaceVariant;
      statusText = "En attente...";
    } else if (isFailed) {
      statusColor = cs.error;
      statusText = "Échec du téléchargement";
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFailed
              ? cs.error.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SonoritizArtwork(
                  imageUrl: task.track.coverUrl,
                  width: 52,
                  height: 52,
                  borderRadius: 10,
                ),
              ),
              if (isDownloading)
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        value: task.progress > 0 ? task.progress : null,
                        strokeWidth: 3,
                        color: cs.primary,
                        backgroundColor: cs.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                )
              else if (isPaused)
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child:
                        Icon(Icons.pause_rounded, color: Colors.white, size: 24),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.track.title.isNotEmpty
                      ? task.track.title
                      : "Titre inconnu",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  task.track.artistName.isNotEmpty
                      ? task.track.artistName
                      : "Artiste inconnu",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: isQueued ? null : task.progress,
                          minHeight: 4,
                          color: statusColor,
                          backgroundColor: statusColor.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: tt.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDownloading)
                IconButton(
                  icon:
                      const Icon(Icons.pause_circle_outline_rounded, size: 24),
                  tooltip: "Mettre en pause",
                  color: cs.primary,
                  onPressed: () => cubit.pauseDownload(task.track.id),
                )
              else if (isPaused)
                IconButton(
                  icon:
                      const Icon(Icons.play_circle_outline_rounded, size: 24),
                  tooltip: "Reprendre",
                  color: const Color(0xFFFE9920),
                  onPressed: () => cubit.resumeDownload(task.track.id),
                )
              else if (isFailed)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 24),
                  tooltip: "Réessayer",
                  color: cs.primary,
                  onPressed: () => cubit.retryDownload(task.track.id),
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: "Annuler",
                color: cs.onSurfaceVariant,
                onPressed: () => cubit.cancelDownload(task.track.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(
      BuildContext context, MapEntry<String, List<OfflineTrackModel>> album) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = album.key;
    final tracks = album.value;
    final firstTrack = tracks.first;
    final coverPath = firstTrack.localCoverPath;
    final artistName = firstTrack.track.artistName;

    return GestureDetector(
      onTap: () => _showOfflineAlbumBottomSheet(
          context, title, artistName, coverPath, tracks),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: SonoritizArtwork(
                    imageUrl: coverPath.isNotEmpty ? 'file://$coverPath' : '',
                    width: 140,
                    height: 140,
                    borderRadius: 12,
                    fallbackIcon:
                        Icon(Icons.album, size: 50, color: cs.onSurfaceVariant),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${tracks.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              "$artistName · ${tracks.length} titres",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.download_for_offline_outlined,
                  size: 46, color: cs.primary.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            Text("Aucun téléchargement",
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              "Les titres téléchargés s'écoutent sans connexion internet.",
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.explore_rounded),
              label: const Text("Explorer la musique"),
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchState(BuildContext context, String rawQuery) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 42,
                color: cs.primary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Aucun son trouvé pour « ${rawQuery.trim()} »",
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Vérifiez l'orthographe du titre ou du nom de l'artiste.",
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => context.read<LibraryUiCubit>().closeSearch(),
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text("Effacer la recherche"),
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBar(
      BuildContext context, List<OfflineTrackModel> offlineTracks) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final count = _selectedTrackIds.length;

    return Positioned(
      bottom: 160 + MediaQuery.of(context).padding.bottom,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xF71E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: count == offlineTracks.length && offlineTracks.isNotEmpty
                  ? () => setState(() => _selectedTrackIds.clear())
                  : () => _selectAll(offlineTracks),
              icon: Icon(
                count == offlineTracks.length && offlineTracks.isNotEmpty
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
                size: 18,
              ),
              label: Text(count == offlineTracks.length && offlineTracks.isNotEmpty
                  ? "Tout désélect."
                  : "Tout"),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurface,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
            Expanded(
              child: Text(
                count == 0
                    ? "Sélectionner..."
                    : "$count sélectionné${count > 1 ? 's' : ''}",
                textAlign: TextAlign.center,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (count > 0)
              IconButton(
                icon: const Icon(Icons.playlist_add_rounded, size: 22),
                tooltip: "Ajouter à une playlist",
                color: cs.primary,
                onPressed: () {
                  final selected = offlineTracks
                      .where((ot) => _selectedTrackIds.contains(ot.track.id))
                      .map((ot) => ot.track)
                      .toList();
                  _showPlaylistsSelectionForMultiple(context, selected);
                },
              ),
            if (count > 0)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 22),
                tooltip: "Supprimer",
                color: cs.error,
                onPressed: () => _showDeleteConfirmDialog(context, count),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, int count) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, anim, anim2) {
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.82,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xF7202020),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18), width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10))
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cs.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delete_forever_rounded,
                        color: cs.error, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Supprimer $count titre${count > 1 ? 's' : ''} ?",
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Les fichiers seront supprimés de votre appareil. Vous pourrez les retélécharger plus tard.",
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3)),
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text("Annuler"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            for (final trackId in _selectedTrackIds) {
                              context
                                  .read<DownloadCubit>()
                                  .removeDownload(trackId);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    "$count titre${count > 1 ? 's' : ''} supprimé${count > 1 ? 's' : ''}"),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _toggleSelectionMode();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.error,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text("Supprimer"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<DownloadCubit, DownloadState>(
      builder: (context, state) {
        if (state is! DownloadStateData) {
          return const Center(child: CircularProgressIndicator());
        }

        final offlineTracks = state.offlineTracks;
        final activeTasks = state.activeTasks;

        if (offlineTracks.isEmpty && activeTasks.isEmpty) {
          return _buildEmptyState(context);
        }

        return BlocBuilder<LibraryUiCubit, LibraryUiState>(
          builder: (context, uiState) {
            final viewMode = uiState.getViewModeFor('downloads');
            final sortMode = uiState.getSortModeFor('downloads');
            final normalizedQuery =
                LibraryUiCubit.normalizeForSearch(uiState.searchQuery);

            final filteredOfflineTracks = normalizedQuery.isEmpty
                ? offlineTracks
                : offlineTracks
                    .where((ot) => _matchesTrackQuery(ot.track, normalizedQuery))
                    .toList();

            final filteredActiveTasksList = normalizedQuery.isEmpty
                ? activeTasks.values.toList()
                : activeTasks.values
                    .where(
                        (task) => _matchesTrackQuery(task.track, normalizedQuery))
                    .toList();

            // Group tracks by album (filtré si recherche active)
            final Map<String, List<OfflineTrackModel>> albumsMap = {};
            for (final ot in offlineTracks) {
              final albumName = ot.track.albumName.trim();
              if (albumName.isNotEmpty &&
                  albumName != 'YouTube Audio' &&
                  albumName != 'Sonoritiz' &&
                  albumName != 'Top Titres' &&
                  albumName != 'Deezer Top') {
                albumsMap.putIfAbsent(albumName, () => []).add(ot);
              }
            }
            final downloadedAlbums = normalizedQuery.isEmpty
                ? albumsMap.entries.toList()
                : albumsMap.entries.where((entry) {
                    if (LibraryUiCubit.normalizeForSearch(entry.key)
                        .contains(normalizedQuery)) {
                      return true;
                    }
                    return entry.value.any(
                        (ot) => _matchesTrackQuery(ot.track, normalizedQuery));
                  }).toList();

            if (normalizedQuery.isNotEmpty &&
                filteredOfflineTracks.isEmpty &&
                filteredActiveTasksList.isEmpty &&
                downloadedAlbums.isEmpty) {
              return _buildEmptySearchState(context, uiState.searchQuery);
            }

            final Map<String, String> localCoverPaths = {
              for (final ot in offlineTracks) ot.track.id: ot.localCoverPath
            };

            final rawTracks =
                filteredOfflineTracks.map((e) => e.track).toList();
            final sortedTracks = TrackGridView.sortTracks(rawTracks, sortMode);

            return Stack(
              children: [
                SonoritizFastScrollbar(
                  itemCount: sortedTracks.length,
                  bottomMargin: _isSelectionMode ? 220 : 110,
                  labelBuilder: (idx) {
                    final t = sortedTracks[idx];
                    if (sortMode == SortMode.alpha) {
                      final clean = t.title.trim();
                      if (clean.isNotEmpty) {
                        final firstChar = clean[0].toUpperCase();
                        return RegExp(r'[A-ZÀ-Ÿ0-9]').hasMatch(firstChar)
                            ? firstChar
                            : '#';
                      }
                    }
                    return '${idx + 1}';
                  },
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // ── 1. DOWNLOADS IN PROGRESS ──────────────────────
                      if (filteredActiveTasksList.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _buildSectionHeader(
                            "Téléchargements en cours",
                            filteredActiveTasksList.length,
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildDownloadingCard(
                              context,
                              filteredActiveTasksList[index],
                            ),
                            childCount: filteredActiveTasksList.length,
                          ),
                        ),
                      ],

                      // ── 2. ALBUMS ─────────────────────────────────────
                      if (downloadedAlbums.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _buildSectionHeader(
                            "Albums téléchargés",
                            downloadedAlbums.length,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 195,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: downloadedAlbums.length,
                              itemBuilder: (context, index) => _buildAlbumCard(
                                  context, downloadedAlbums[index]),
                            ),
                          ),
                        ),
                      ],

                      // ── 3. DOWNLOADED TRACKS ──────────────────────────
                      if (sortedTracks.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _buildSectionHeader(
                            normalizedQuery.isEmpty
                                ? "Sons téléchargés"
                                : "Résultats téléchargés",
                            sortedTracks.length,
                            trailing: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: IconButton(
                                key: ValueKey(_isSelectionMode),
                                icon: Icon(
                                  _isSelectionMode
                                      ? Icons.close_rounded
                                      : Icons.checklist_rounded,
                                ),
                                tooltip: _isSelectionMode
                                    ? "Annuler"
                                    : "Sélectionner",
                                onPressed: _toggleSelectionMode,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _isSelectionMode
                                ? const SizedBox.shrink()
                                : Padding(
                                    key: const ValueKey('playButtons'),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton.icon(
                                            onPressed: () {
                                              context
                                                  .read<PlayerCubit>()
                                                  .playTrack(
                                                    sortedTracks.first,
                                                    queue: sortedTracks,
                                                    source:
                                                        'les téléchargements',
                                                  );
                                            },
                                            icon: const Icon(
                                                Icons.play_arrow_rounded),
                                            label: const Text("Lire"),
                                            style: FilledButton.styleFrom(
                                              shape: const StadiumBorder(),
                                              minimumSize: const Size(
                                                double.infinity,
                                                AppDimensions.buttonHeight,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              final shuffled =
                                                  List<TrackModel>.from(
                                                      sortedTracks)
                                                    ..shuffle();
                                              context
                                                  .read<PlayerCubit>()
                                                  .playTrack(
                                                    shuffled.first,
                                                    queue: shuffled,
                                                    source:
                                                        'les téléchargements',
                                                  );
                                            },
                                            icon: const Icon(
                                                Icons.shuffle_rounded),
                                            label: const Text("Aléatoire"),
                                            style: OutlinedButton.styleFrom(
                                              shape: const StadiumBorder(),
                                              minimumSize: const Size(
                                                double.infinity,
                                                AppDimensions.buttonHeight,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),

                        // Virtualisation Sliver directe (sans shrinkWrap)
                        TrackGridView(
                          key: ValueKey('${viewMode.name}_${sortMode.name}'),
                          tracks: rawTracks,
                          viewMode: viewMode,
                          sortMode: sortMode,
                          localCoverPaths: localCoverPaths,
                          isSelectionMode: _isSelectionMode,
                          selectedTrackIds: _selectedTrackIds,
                          onSelectionChanged: _onSelectionChanged,
                          playbackSource: 'les téléchargements',
                        ),
                      ],

                      SliverToBoxAdapter(
                        child: SizedBox(height: _isSelectionMode ? 200 : 120),
                      ),
                    ],
                  ),
                ),

                if (_isSelectionMode)
                  _buildSelectionBar(context, filteredOfflineTracks),
              ],
            );
          },
        );
      },
    );
  }

  void _showOfflineAlbumBottomSheet(BuildContext context, String title,
      String artistName, String coverPath, List<OfflineTrackModel> tracks) {
    final trackList = tracks.map((e) => e.track).toList();

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            final cs = Theme.of(context).colorScheme;
            final tt = Theme.of(context).textTheme;
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: SonoritizCoverAtmosphere(
                coverUrl: coverPath.isNotEmpty ? 'file://$coverPath' : '',
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Column(
                          children: [
                            Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(2))),
                            const SizedBox(height: 20),
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: cs.surfaceContainerHighest,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      blurRadius: 24,
                                      offset: const Offset(0, 12))
                                ],
                              ),
                              child: SonoritizArtwork(
                                imageUrl: coverPath.isNotEmpty
                                    ? 'file://$coverPath'
                                    : '',
                                width: 200,
                                height: 200,
                                borderRadius: 18,
                                fallbackIcon: Icon(Icons.album,
                                    size: 80, color: cs.onSurfaceVariant),
                              ),
                            ),
                            const SizedBox(height: 18),
                            SonoritizPageTitle(
                              title: title,
                              fontSize: 25,
                              maxLines: 2,
                              centered: true,
                            ),
                            const SizedBox(height: 6),
                            Text("$artistName · ${tracks.length} titres",
                                style: tt.titleMedium
                                    ?.copyWith(color: Colors.white70)),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      context
                                          .read<PlayerCubit>()
                                          .playTrack(trackList.first,
                                              queue: trackList);
                                    },
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text(
                                      "Lire",
                                      style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800),
                                    ),
                                    style: FilledButton.styleFrom(
                                      foregroundColor: Colors.black,
                                      shape: const StadiumBorder(),
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      final shuffled =
                                          List<TrackModel>.from(trackList)
                                            ..shuffle();
                                      context
                                          .read<PlayerCubit>()
                                          .playTrack(shuffled.first,
                                              queue: shuffled);
                                    },
                                    icon: const Icon(Icons.shuffle_rounded),
                                    label: const Text(
                                      "Aléatoire",
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                          color: Colors.white
                                              .withValues(alpha: 0.2)),
                                      shape: const StadiumBorder(),
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 24),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = tracks[index].track;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 3),
                            leading: SizedBox(
                              width: 28,
                              child: Text(
                                '${index + 1}',
                                style: tt.bodyMedium?.copyWith(
                                    color: Colors.white54,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            title: Text(track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(track.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 14)),
                            trailing: Text(
                              _formatDuration(track.durationSeconds),
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.58),
                                  fontSize: 13.5),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              context
                                  .read<PlayerCubit>()
                                  .playTrack(track, queue: trackList);
                            },
                          );
                        },
                        childCount: tracks.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
