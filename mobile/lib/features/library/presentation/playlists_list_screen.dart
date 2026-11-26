import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/collection_context_menu.dart';
import '../../../core/widgets/playlist_cover_mosaic.dart';
import '../../../core/widgets/playlist_editor_sheet.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../data/repositories/library_repository.dart';
import 'cubit/library_cubit.dart';
import 'cubit/library_ui_cubit.dart';

class PlaylistsListScreen extends StatelessWidget {
  final List<PlaylistModel> playlists;

  const PlaylistsListScreen({Key? key, required this.playlists}) : super(key: key);

  Future<void> _openCreatePlaylistSheet(BuildContext context) async {
    final created = await PlaylistEditorSheet.show(context);
    if (created != null && context.mounted) {
      _openPlaylist(context, created);
    }
  }

  void _showPlaylistContextMenu(BuildContext context, PlaylistModel playlist) {
    CollectionContextMenu.showForPlaylist(
      context,
      playlist: playlist,
      onEdit: () =>
          PlaylistEditorSheet.show(context, existingPlaylist: playlist),
      onTogglePin: () => context
          .read<LibraryCubit>()
          .togglePinPlaylist(playlist.id, playlist.isPinned),
      onDelete: () => _confirmDelete(context, playlist),
    );
  }

  void _confirmDelete(BuildContext context, PlaylistModel playlist) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF16161B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Supprimer la playlist",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          "Veux-tu vraiment supprimer « ${playlist.name} » ?",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              "Annuler",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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

  String _formatDurationSummary(PlaylistModel playlist) {
    if (playlist.tracks.isEmpty) return '';
    int totalSeconds = 0;
    for (final t in playlist.tracks) {
      totalSeconds += t.durationSeconds > 0 ? t.durationSeconds : 195;
    }
    final hours = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '$hours h ${mins.toString().padLeft(2, '0')} min';
    return '$mins min';
  }

  String _formatTracksSubtitle(PlaylistModel playlist) {
    final count = playlist.tracks.isNotEmpty ? playlist.tracks.length : playlist.tracksCount;
    final countLabel = "$count ${count > 1 ? 'titres' : 'titre'}";
    final durationStr = _formatDurationSummary(playlist);
    return durationStr.isNotEmpty ? "$countLabel • $durationStr" : countLabel;
  }

  String _extractArtistsSummary(PlaylistModel playlist) {
    final seen = <String>{};
    final names = <String>[];
    for (final t in playlist.tracks) {
      final raw = t.artistName.trim();
      if (raw.isEmpty) continue;
      final primary = raw
          .split(RegExp(r'\s*(?:,|feat\.?|ft\.?|&)\s*', caseSensitive: false))
          .first
          .trim();
      if (primary.isNotEmpty && seen.add(primary.toLowerCase())) {
        names.add(primary);
        if (names.length >= 2) break;
      }
    }
    return names.join(', ');
  }

  int _compareByRecency(PlaylistModel a, PlaylistModel b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    // Les playlists locales non encore synchronisées (id < 0, -epochMs) restent tout en haut,
    // la plus négative (la plus récente) en premier.
    if (a.id < 0 && b.id < 0) return a.id.compareTo(b.id);
    if (a.id < 0) return -1;
    if (b.id < 0) return 1;
    return b.id.compareTo(a.id);
  }

  void _openPlaylist(BuildContext context, PlaylistModel playlist) {
    context.push('/playlist', extra: playlist);
  }

  void _playPlaylistDirect(BuildContext context, PlaylistModel playlist) {
    if (playlist.tracks.isEmpty) {
      _openPlaylist(context, playlist);
      return;
    }
    context.read<PlayerCubit>().playTrack(
          playlist.tracks.first,
          queue: playlist.tracks,
          source: 'la playlist ${playlist.name}',
        );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: playlists.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.queue_music_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ).animate().scale(
                          delay: AppAnimations.normal,
                          duration: AppAnimations.slow,
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 20),
                    Text(
                      "Aucune playlist",
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ).animate().fadeIn(delay: AppAnimations.slow),
                    const SizedBox(height: 8),
                    Text(
                      "Crée ta première playlist et rassemble tes titres préférés.",
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ).animate().fadeIn(delay: AppAnimations.slow),
                    const SizedBox(height: 26),
                    ElevatedButton.icon(
                      onPressed: () => _openCreatePlaylistSheet(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(
                        "Créer une playlist",
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                      ),
                    ).animate().fadeIn(delay: AppAnimations.slow),
                  ],
                ),
              ),
            )
          : BlocBuilder<LibraryUiCubit, LibraryUiState>(
              builder: (context, uiState) {
                final sortedPlaylists = List<PlaylistModel>.from(playlists);
                final currentSortMode = uiState.getSortModeFor('playlists');

                if (currentSortMode == SortMode.alpha) {
                  sortedPlaylists.sort((a, b) {
                    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  });
                } else {
                  sortedPlaylists.sort(_compareByRecency);
                }

                final currentViewMode = uiState.getViewModeFor('playlists');
                final double screenWidth = MediaQuery.sizeOf(context).width;
                final int baseCols = ResponsiveUtils.adaptiveGridColumns(
                  screenWidth,
                  narrow: 2,
                  mobile: 2,
                  medium: 3,
                  expanded: 4,
                  ultraWide: 5,
                );

                int crossAxisCount;
                double childAspectRatio;
                switch (currentViewMode) {
                  case ViewMode.gridSmall:
                    crossAxisCount = screenWidth < 350 ? 2 : (baseCols + 1);
                    childAspectRatio = 0.66;
                    break;
                  case ViewMode.gridLarge:
                  case ViewMode.cards:
                    crossAxisCount = screenWidth >= 1024 ? 3 : (screenWidth >= 600 ? 2 : 1);
                    childAspectRatio = 2.2;
                    break;
                  case ViewMode.gridMedium:
                  default:
                    crossAxisCount = baseCols;
                    childAspectRatio = 0.74;
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          children: [
                            Text(
                              '${playlists.length} ${playlists.length > 1 ? "playlists" : "playlist"}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _openCreatePlaylistSheet(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.22),
                                      const Color(0xFF16161D),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      "Nouvelle playlist",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
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
                    ),
                    if (currentViewMode == ViewMode.list ||
                        currentViewMode == ViewMode.listCompact)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildListItem(
                            context,
                            sortedPlaylists[index],
                            compact: currentViewMode == ViewMode.listCompact,
                          ),
                          childCount: sortedPlaylists.length,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: childAspectRatio,
                            crossAxisSpacing: currentViewMode == ViewMode.gridSmall ? 12 : 16,
                            mainAxisSpacing: currentViewMode == ViewMode.gridSmall ? 16 : 20,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildGridItem(
                              context,
                              sortedPlaylists[index],
                              currentViewMode,
                            ),
                            childCount: sortedPlaylists.length,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildListItem(
    BuildContext context,
    PlaylistModel playlist, {
    required bool compact,
  }) {
    final coverWidth = compact ? 50.0 : 66.0;
    final coverHeight = compact ? 52.0 : 70.0;

    return Semantics(
      button: true,
      label: "Ouvrir la playlist ${playlist.name}",
      child: InkWell(
        onTap: () => _openPlaylist(context, playlist),
        onLongPress: () => _showPlaylistContextMenu(context, playlist),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: compact ? 6 : 8,
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(compact ? 8 : 11),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PlaylistCoverMosaic(
                  playlist: playlist,
                  size: coverWidth,
                  height: coverHeight,
                  borderRadius: compact ? 8 : 11,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (playlist.isPinned) ...[
                          const Icon(
                            Icons.push_pin_rounded,
                            color: AppColors.primary,
                            size: 13.5,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 14.5 : 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatTracksSubtitle(playlist),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact && playlist.tracks.isNotEmpty)
                IconButton(
                  tooltip: "Lire",
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _playPlaylistDirect(context, playlist),
                  icon: Icon(
                    Icons.play_circle_fill_rounded,
                    color: AppColors.primary.withValues(alpha: 0.92),
                    size: 28,
                  ),
                ),
              IconButton(
                tooltip: "Options",
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                onPressed: () => _showPlaylistContextMenu(context, playlist),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, PlaylistModel playlist, ViewMode mode) {
    final isPanoramic = mode == ViewMode.gridLarge || mode == ViewMode.cards;
    final artistsStr = _extractArtistsSummary(playlist);

    if (isPanoramic) {
      return Semantics(
        button: true,
        label: "Ouvrir la playlist ${playlist.name}",
        child: Material(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openPlaylist(context, playlist),
            onLongPress: () => _showPlaylistContextMenu(context, playlist),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  PlaylistCoverMosaic(
                    playlist: playlist,
                    size: 122,
                    height: 130,
                    borderRadius: 13,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (playlist.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.push_pin_rounded, color: AppColors.primary, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  "Épinglée",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          playlist.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (artistsStr.isNotEmpty) ...[
                          Text(
                            artistsStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                        Text(
                          _formatTracksSubtitle(playlist),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (playlist.tracks.isNotEmpty)
                              GestureDetector(
                                onTap: () => _playPlaylistDirect(context, playlist),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.all(Radius.circular(20)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_arrow_rounded, color: Colors.black, size: 17),
                                      SizedBox(width: 4),
                                      Text(
                                        "Lire",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const Spacer(),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                              onPressed: () => _showPlaylistContextMenu(context, playlist),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Grille épurée 2 ou 3 colonnes : pochettes mises en valeur sans cadre épais
    final isCompactGrid = mode == ViewMode.gridSmall;
    final radius = isCompactGrid ? 10.0 : 14.0;

    return Semantics(
      button: true,
      label: "Ouvrir la playlist ${playlist.name}",
      child: GestureDetector(
        onTap: () => _openPlaylist(context, playlist),
        onLongPress: () => _showPlaylistContextMenu(context, playlist),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.42),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: PlaylistCoverMosaic(
                      playlist: playlist,
                      size: double.infinity,
                      height: double.infinity,
                      borderRadius: radius,
                    ),
                  ),
                  if (playlist.isPinned)
                    Positioned(
                      top: 7,
                      left: 7,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.68),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.push_pin_rounded,
                          color: AppColors.primary,
                          size: 12,
                        ),
                      ),
                    ),
                  if (!isCompactGrid && playlist.tracks.isNotEmpty)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: GestureDetector(
                        onTap: () => _playPlaylistDirect(context, playlist),
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
            ),
            const SizedBox(height: 8),
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompactGrid ? 12.5 : 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isCompactGrid
                  ? "${playlist.tracks.isNotEmpty ? playlist.tracks.length : playlist.tracksCount} titres"
                  : _formatTracksSubtitle(playlist),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: isCompactGrid ? 11 : 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
