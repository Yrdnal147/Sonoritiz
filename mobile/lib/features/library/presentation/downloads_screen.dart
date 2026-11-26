import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/collection_context_menu.dart';
import '../../../core/widgets/sonoritiz_artwork.dart';
import '../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../core/widgets/sonoritiz_fast_scrollbar.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../../core/widgets/track_context_menu.dart';
import '../../../core/widgets/track_grid_view.dart';
import '../../offline/data/models/offline_track_model.dart';
import '../../offline/presentation/cubit/download_cubit.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import 'cubit/library_cubit.dart';
import 'cubit/library_state.dart';
import 'cubit/library_ui_cubit.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _ResolvedDownloadedAlbum {
  final String id;
  final String title;
  final String artistName;
  final String coverUrl;
  final List<String> registeredTrackIds;
  final List<OfflineTrackModel> offlineTracks;
  final int activePendingCount;

  const _ResolvedDownloadedAlbum({
    required this.id,
    required this.title,
    required this.artistName,
    required this.coverUrl,
    required this.registeredTrackIds,
    required this.offlineTracks,
    required this.activePendingCount,
  });

  int get expectedCount => registeredTrackIds.isNotEmpty
      ? registeredTrackIds.length
      : offlineTracks.length;

  String get effectiveCoverUrl {
    for (final ot in offlineTracks) {
      if (!kIsWeb &&
          ot.localCoverPath.isNotEmpty &&
          File(ot.localCoverPath).existsSync()) {
        return 'file://${ot.localCoverPath}';
      }
    }
    if (coverUrl.isNotEmpty) return coverUrl;
    for (final ot in offlineTracks) {
      if (ot.track.coverUrl.isNotEmpty) return ot.track.coverUrl;
    }
    return '';
  }
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

  List<_ResolvedDownloadedAlbum> _resolveRealDownloadedAlbums({
    required List<Map<String, dynamic>> rawRegisteredAlbums,
    required List<OfflineTrackModel> offlineTracks,
    required Map<String, ActiveDownloadTask> activeTasks,
    required String normalizedQuery,
  }) {
    if (rawRegisteredAlbums.isEmpty) return const [];

    final offlineById = <String, OfflineTrackModel>{
      for (final ot in offlineTracks) ot.track.id: ot,
    };

    final resolved = <_ResolvedDownloadedAlbum>[];
    for (final reg in rawRegisteredAlbums) {
      final id = (reg['id'] ?? '').toString().trim();
      final title = (reg['title'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final artistName = (reg['artistName'] ?? 'Artiste').toString().trim();
      final coverUrl = (reg['coverUrl'] ?? '').toString().trim();
      final trackIds = (reg['trackIds'] as List? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final matched = <OfflineTrackModel>[];
      final seenIds = <String>{};

      for (final tid in trackIds) {
        final found = offlineById[tid];
        if (found != null && seenIds.add(found.track.id)) {
          matched.add(found);
        }
      }

      // Fallback de correspondance uniquement pour cet album explicitement enregistré
      final normTitle = LibraryUiCubit.normalizeForSearch(title);
      for (final ot in offlineTracks) {
        if (seenIds.contains(ot.track.id)) continue;
        final otAlbumNorm =
            LibraryUiCubit.normalizeForSearch(ot.track.albumName);
        if (otAlbumNorm.isNotEmpty && otAlbumNorm == normTitle) {
          seenIds.add(ot.track.id);
          matched.add(ot);
        }
      }

      int pendingCount = 0;
      for (final tid in trackIds) {
        if (activeTasks.containsKey(tid)) pendingCount++;
      }

      // N'afficher l'album que s'il a au moins 1 piste téléchargée ou en cours
      if (matched.isEmpty && pendingCount == 0) continue;

      if (normalizedQuery.isNotEmpty) {
        final matchesMeta =
            normTitle.contains(normalizedQuery) ||
            LibraryUiCubit.normalizeForSearch(artistName)
                .contains(normalizedQuery) ||
            matched.any((ot) => _matchesTrackQuery(ot.track, normalizedQuery));
        if (!matchesMeta) continue;
      }

      resolved.add(
        _ResolvedDownloadedAlbum(
          id: id.isNotEmpty ? id : title,
          title: title,
          artistName: artistName,
          coverUrl: coverUrl,
          registeredTrackIds: trackIds,
          offlineTracks: matched,
          activePendingCount: pendingCount,
        ),
      );
    }

    return resolved;
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
          backgroundColor: const Color(0xFF16161D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.playlist_add_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Ajouter ${tracks.length} titre${tracks.length > 1 ? 's' : ''}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              if (playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Text(
                    "Aucune playlist disponible.\nCréez une playlist d'abord.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
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
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.16),
                          child: const Icon(
                            Icons.queue_music_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          playlist.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          "${playlist.tracks?.length ?? 0} titres",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.56),
                          ),
                        ),
                        onTap: () {
                          parentContext
                              .read<LibraryCubit>()
                              .addMultipleTracksToPlaylist(
                                  playlist.id, tracks);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF181820),
                              content: Text(
                                "${tracks.length} titre${tracks.length > 1 ? 's' : ''} ajouté${tracks.length > 1 ? 's' : ''} à « ${playlist.name} »",
                                style: const TextStyle(color: Colors.white),
                              ),
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
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Annuler",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
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

    Color statusColor = AppColors.primary;
    String statusText = "${(task.progress * 100).toInt()}%";
    if (isPaused) {
      statusColor = const Color(0xFFFE9920);
      statusText = "En pause (${(task.progress * 100).toInt()}%)";
    } else if (isQueued) {
      statusColor = Colors.white60;
      statusText = "En attente...";
    } else if (isFailed) {
      statusColor = cs.error;
      statusText = "Échec du téléchargement";
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14141B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFailed
              ? cs.error.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: SonoritizArtwork(
                  imageUrl: task.track.coverUrl,
                  width: 52,
                  height: 52,
                  borderRadius: 11,
                ),
              ),
              if (isDownloading)
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        value: task.progress > 0 ? task.progress : null,
                        strokeWidth: 2.8,
                        color: AppColors.primary,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.2),
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
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.pause_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
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
                  style: tt.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.track.artistName.isNotEmpty
                      ? task.track.artistName
                      : "Artiste inconnu",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
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
                        fontWeight: FontWeight.w700,
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
                  color: AppColors.primary,
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
                  color: AppColors.primary,
                  onPressed: () => cubit.retryDownload(task.track.id),
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: "Annuler",
                color: Colors.white54,
                onPressed: () => cubit.cancelDownload(task.track.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(
    BuildContext context,
    _ResolvedDownloadedAlbum album,
  ) {
    final trackList = album.offlineTracks.map((e) => e.track).toList();
    final effectiveCover = album.effectiveCoverUrl;
    final countLabel = album.activePendingCount > 0
        ? "${album.offlineTracks.length}/${album.expectedCount} titres"
        : "${album.offlineTracks.length} ${album.offlineTracks.length > 1 ? 'titres' : 'titre'}";

    void openContextMenu() {
      CollectionContextMenu.showForAlbum(
        context,
        albumId: album.id,
        title: album.title,
        artistName: album.artistName,
        coverUrl: effectiveCover,
        preloadedTracks: trackList.isNotEmpty ? trackList : null,
      );
    }

    return GestureDetector(
      onTap: () => _showOfflineAlbumBottomSheet(context, album),
      onLongPress: openContextMenu,
      child: Container(
        width: 148,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.36),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: SonoritizArtwork(
                    imageUrl: effectiveCover,
                    width: 148,
                    height: 148,
                    borderRadius: 16,
                    fallbackIcon: const Icon(
                      Icons.album_rounded,
                      size: 50,
                      color: Colors.white30,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.45),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.download_done_rounded,
                          color: AppColors.primary,
                          size: 11,
                        ),
                        SizedBox(width: 3),
                        Text(
                          "ALBUM",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: openContextMenu,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                if (trackList.isNotEmpty)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: GestureDetector(
                      onTap: () {
                        context.read<PlayerCubit>().playTrack(
                              trackList.first,
                              queue: trackList,
                              source: "${album.artistName} • ${album.title}",
                            );
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "${album.artistName} • $countLabel",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 38),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.download_for_offline_outlined,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Aucun téléchargement",
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Télécharge tes albums ou sons préférés pour les écouter partout sans connexion.",
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 26),
            GestureDetector(
              onTap: () => context.go('/home'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.explore_rounded,
                      color: Colors.black,
                      size: 19,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Explorer la musique",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchState(BuildContext context, String rawQuery) {
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
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Aucun téléchargement trouvé pour « ${rawQuery.trim()} »",
              textAlign: TextAlign.center,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Vérifie l'orthographe du titre, de l'album ou de l'artiste.",
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.58),
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => context.read<LibraryUiCubit>().closeSearch(),
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text("Effacer la recherche"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
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
          color: const Color(0xF716161D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            TextButton.icon(
              onPressed:
                  count == offlineTracks.length && offlineTracks.isNotEmpty
                      ? () => setState(() => _selectedTrackIds.clear())
                      : () => _selectAll(offlineTracks),
              icon: Icon(
                count == offlineTracks.length && offlineTracks.isNotEmpty
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
                size: 18,
              ),
              label: Text(
                count == offlineTracks.length && offlineTracks.isNotEmpty
                    ? "Tout désélect."
                    : "Tout",
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
            Expanded(
              child: Text(
                count == 0
                    ? "Sélectionner..."
                    : "$count sélectionné${count > 1 ? 's' : ''}",
                textAlign: TextAlign.center,
                style: tt.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (count > 0)
              IconButton(
                icon: const Icon(Icons.playlist_add_rounded, size: 22),
                tooltip: "Ajouter à une playlist",
                color: AppColors.primary,
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
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (ctx, anim, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, anim, anim2) {
        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.84,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF16161D),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
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
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: cs.error,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Supprimer $count titre${count > 1 ? 's' : ''} ?",
                    style: tt.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Les fichiers seront supprimés de votre appareil. Vous pourrez les retélécharger plus tard.",
                    style: tt.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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
                                backgroundColor: const Color(0xFF181820),
                                content: Text(
                                  "$count titre${count > 1 ? 's' : ''} supprimé${count > 1 ? 's' : ''}",
                                  style: const TextStyle(color: Colors.white),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _toggleSelectionMode();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.error,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
          );
        }

        final offlineTracks = state.offlineTracks;
        final activeTasks = state.activeTasks;

        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: StorageService.downloadedAlbumsNotifier,
          builder: (context, rawRegisteredAlbums, _) {
            if (offlineTracks.isEmpty &&
                activeTasks.isEmpty &&
                rawRegisteredAlbums.isEmpty) {
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
                        .where((ot) =>
                            _matchesTrackQuery(ot.track, normalizedQuery))
                        .toList();

                final filteredActiveTasksList = normalizedQuery.isEmpty
                    ? activeTasks.values.toList()
                    : activeTasks.values
                        .where((task) =>
                            _matchesTrackQuery(task.track, normalizedQuery))
                        .toList();

                // RÈGLE STRICTE : « Albums téléchargés » n'affiche QUE les vrais albums
                // explicitement téléchargés en tant qu'albums (jamais un son isolé !).
                final downloadedAlbums = _resolveRealDownloadedAlbums(
                  rawRegisteredAlbums: rawRegisteredAlbums,
                  offlineTracks: offlineTracks,
                  activeTasks: activeTasks,
                  normalizedQuery: normalizedQuery,
                );

                if (offlineTracks.isEmpty &&
                    activeTasks.isEmpty &&
                    downloadedAlbums.isEmpty) {
                  return _buildEmptyState(context);
                }

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
                final sortedTracks =
                    TrackGridView.sortTracks(rawTracks, sortMode);

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
                          // ── 1. TÉLÉCHARGEMENTS EN COURS ──────────────────
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

                          // ── 2. VRAIS ALBUMS TÉLÉCHARGÉS ──────────────────
                          if (downloadedAlbums.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _buildSectionHeader(
                                "Albums téléchargés",
                                downloadedAlbums.length,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: 204,
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: downloadedAlbums.length,
                                  itemBuilder: (context, index) =>
                                      _buildAlbumCard(
                                    context,
                                    downloadedAlbums[index],
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // ── 3. SONS TÉLÉCHARGÉS ──────────────────────────
                          if (sortedTracks.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                child: Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 11, 10, 11),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF14141B),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              normalizedQuery.isEmpty
                                                  ? "Sons téléchargés"
                                                  : "Résultats téléchargés",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "${sortedTracks.length} ${sortedTracks.length > 1 ? 'titres hors-ligne' : 'titre hors-ligne'}",
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.56),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!_isSelectionMode) ...[
                                        GestureDetector(
                                          onTap: () {
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
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.14),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.shuffle_rounded,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  "Aléatoire",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        GestureDetector(
                                          onTap: () {
                                            context
                                                .read<PlayerCubit>()
                                                .playTrack(
                                                  sortedTracks.first,
                                                  queue: sortedTracks,
                                                  source:
                                                      'les téléchargements',
                                                );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.play_arrow_rounded,
                                                  color: Colors.black,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 3),
                                                Text(
                                                  "Lire",
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(
                                          _isSelectionMode
                                              ? Icons.close_rounded
                                              : Icons.checklist_rounded,
                                          color: _isSelectionMode
                                              ? AppColors.primary
                                              : Colors.white70,
                                          size: 20,
                                        ),
                                        tooltip: _isSelectionMode
                                            ? "Fermer la sélection"
                                            : "Sélectionner",
                                        onPressed: _toggleSelectionMode,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            TrackGridView(
                              key: ValueKey(
                                  '${viewMode.name}_${sortMode.name}'),
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
                            child: SizedBox(
                              height: _isSelectionMode ? 200 : 120,
                            ),
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
      },
    );
  }

  void _showOfflineAlbumBottomSheet(
    BuildContext parentContext,
    _ResolvedDownloadedAlbum album,
  ) {
    final trackList = album.offlineTracks.map((e) => e.track).toList();
    final effectiveCover = album.effectiveCoverUrl;
    final playerCubit = parentContext.read<PlayerCubit>();
    final downloadCubit = parentContext.read<DownloadCubit>();

    showModalBottomSheet(
      context: parentContext,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          maxChildSize: 0.94,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            final tt = Theme.of(context).textTheme;
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
              child: SonoritizCoverAtmosphere(
                coverUrl: effectiveCover,
                child: CustomScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
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
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: 192,
                              height: 192,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: const Color(0xFF16161D),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: SonoritizArtwork(
                                imageUrl: effectiveCover,
                                width: 192,
                                height: 192,
                                borderRadius: 20,
                                fallbackIcon: const Icon(
                                  Icons.album_rounded,
                                  size: 76,
                                  color: Colors.white30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            SonoritizPageTitle(
                              title: album.title,
                              fontSize: 24,
                              maxLines: 2,
                              centered: true,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "${album.artistName} • ${album.offlineTracks.length} ${album.offlineTracks.length > 1 ? 'titres hors-ligne' : 'titre hors-ligne'}",
                              style: tt.titleMedium?.copyWith(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (trackList.isNotEmpty)
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.pop(sheetCtx);
                                        playerCubit.playTrack(
                                          trackList.first,
                                          queue: trackList,
                                          source:
                                              "${album.artistName} • ${album.title}",
                                        );
                                      },
                                      child: Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius:
                                              BorderRadius.circular(24),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.play_arrow_rounded,
                                              color: Colors.black,
                                              size: 22,
                                            ),
                                            SizedBox(width: 5),
                                            Text(
                                              "Lire",
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.pop(sheetCtx);
                                        playerCubit.playTrackListNext(
                                          trackList,
                                          source:
                                              "${album.artistName} • ${album.title}",
                                        );
                                        ScaffoldMessenger.of(parentContext)
                                            .showSnackBar(
                                          SnackBar(
                                            backgroundColor:
                                                const Color(0xFF181820),
                                            behavior: SnackBarBehavior.floating,
                                            content: Text(
                                              "« ${album.title} » sera lu juste après",
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.18),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.playlist_play_rounded,
                                              color: AppColors.primary,
                                              size: 20,
                                            ),
                                            SizedBox(width: 5),
                                            Text(
                                              "Lire ensuite",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () async {
                                      Navigator.pop(sheetCtx);
                                      final idsToRemove = <String>{
                                        ...album.registeredTrackIds,
                                        ...trackList.map((t) => t.id),
                                      }.toList();
                                      await downloadCubit.removeAlbumDownload(
                                        albumId: album.id,
                                        title: album.title,
                                        artistName: album.artistName,
                                        trackIds: idsToRemove,
                                      );
                                      if (!parentContext.mounted) return;
                                      ScaffoldMessenger.of(parentContext)
                                          .showSnackBar(
                                        SnackBar(
                                          backgroundColor:
                                              const Color(0xFF181820),
                                          behavior: SnackBarBehavior.floating,
                                          content: Text(
                                            "Album « ${album.title} » supprimé des téléchargements.",
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent
                                            .withValues(alpha: 0.14),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.redAccent
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 21,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            Divider(
                              height: 24,
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = album.offlineTracks[index].track;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 2,
                            ),
                            leading: SizedBox(
                              width: 28,
                              child: Text(
                                '${index + 1}',
                                style: tt.bodyMedium?.copyWith(
                                  color: Colors.white54,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              track.artistName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 13,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (track.durationSeconds > 0)
                                  Text(
                                    _formatDuration(track.durationSeconds),
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.52),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.more_horiz_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  onPressed: () => TrackContextMenu.show(
                                    parentContext,
                                    track,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(sheetCtx);
                              playerCubit.playTrack(
                                track,
                                queue: trackList,
                                source: "${album.artistName} • ${album.title}",
                              );
                            },
                            onLongPress: () =>
                                TrackContextMenu.show(parentContext, track),
                          );
                        },
                        childCount: album.offlineTracks.length,
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
