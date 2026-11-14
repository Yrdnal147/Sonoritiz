import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artist_name_display.dart';
import '../../../core/widgets/playlist_cover_mosaic.dart';
import '../../../core/widgets/playlist_editor_sheet.dart';
import '../../../core/widgets/playing_indicator_overlay.dart';
import '../../../core/widgets/sonoritiz_cover_atmosphere.dart';
import '../../../core/widgets/sonoritiz_page_title.dart';
import '../../../core/widgets/track_context_menu.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../home/data/repositories/catalog_repository.dart';
import '../../offline/presentation/cubit/download_cubit.dart';
import '../data/repositories/library_repository.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import '../../player/presentation/cubit/player_state.dart';
import 'cubit/library_cubit.dart';
import 'cubit/library_state.dart';

enum PlaylistSortOption {
  custom,
  recentFirst,
  titleAsc,
  artistAsc,
  durationDesc,
}

class PlaylistDetailScreen extends StatefulWidget {
  final PlaylistModel playlist;

  const PlaylistDetailScreen({Key? key, required this.playlist}) : super(key: key);

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<double> _collapseProgress = ValueNotifier<double>(0.0);

  bool _isSearching = false;
  String _searchQuery = '';
  String? _selectedArtistFilter;
  PlaylistSortOption _sortOption = PlaylistSortOption.custom;

  bool _isSelectionMode = false;
  final Set<String> _selectedTrackIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final progress = (_scrollController.offset / 230.0).clamp(0.0, 1.0);
    if ((progress - _collapseProgress.value).abs() > 0.01) {
      _collapseProgress.value = progress;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _collapseProgress.dispose();
    super.dispose();
  }

  String _resolveHeroCoverUrl(PlaylistModel playlist) {
    if (playlist.coverUrl.trim().isNotEmpty) {
      return playlist.coverUrl.trim();
    }
    for (final t in playlist.tracks) {
      if (t.coverUrl.trim().isNotEmpty) {
        return t.coverUrl.trim();
      }
    }
    return '';
  }

  String _formatTotalDuration(List<TrackModel> tracks) {
    int totalSeconds = 0;
    for (final t in tracks) {
      totalSeconds += t.durationSeconds > 0 ? t.durationSeconds : 195;
    }
    if (totalSeconds <= 0) return '0 min';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours h ${minutes.toString().padLeft(2, '0')} min';
    }
    return '$minutes min';
  }

  String _formatTrackDuration(int seconds) {
    if (seconds <= 0) return '';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  List<String> _parseArtistNames(String raw) {
    final sep = RegExp(
      r'(\s+(?:feat\.?|ft\.?|featuring|and|&|x)\s+|,\s+)',
      caseSensitive: false,
    );
    return raw
        .split(sep)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<MapEntry<String, int>> _extractTopArtists(List<TrackModel> tracks) {
    final Map<String, int> counts = {};
    final Map<String, String> displayNames = {};
    for (final t in tracks) {
      final parsed = _parseArtistNames(t.artistName);
      for (final artist in parsed) {
        final key = artist.toLowerCase();
        counts[key] = (counts[key] ?? 0) + 1;
        displayNames.putIfAbsent(key, () => artist);
      }
    }
    final entries = counts.entries
        .map((e) => MapEntry(displayNames[e.key] ?? e.key, e.value))
        .toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  List<TrackModel> _getFilteredAndSortedTracks(List<TrackModel> originalTracks) {
    List<TrackModel> result = List<TrackModel>.from(originalTracks);

    if (_selectedArtistFilter != null && _selectedArtistFilter!.isNotEmpty) {
      final filterLower = _selectedArtistFilter!.toLowerCase();
      result = result.where((t) {
        final artists = _parseArtistNames(t.artistName);
        return artists.any((a) => a.toLowerCase() == filterLower) ||
            t.artistName.toLowerCase().contains(filterLower);
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((t) {
        return t.title.toLowerCase().contains(q) ||
            t.artistName.toLowerCase().contains(q) ||
            t.albumName.toLowerCase().contains(q);
      }).toList();
    }

    switch (_sortOption) {
      case PlaylistSortOption.custom:
        break;
      case PlaylistSortOption.recentFirst:
        result = result.reversed.toList();
        break;
      case PlaylistSortOption.titleAsc:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case PlaylistSortOption.artistAsc:
        result.sort((a, b) => a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase()));
        break;
      case PlaylistSortOption.durationDesc:
        result.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
        break;
    }

    return result;
  }

  String _getSortLabel(PlaylistSortOption option) {
    switch (option) {
      case PlaylistSortOption.custom:
        return 'Ordre personnalisé';
      case PlaylistSortOption.recentFirst:
        return 'Ajoutés récemment';
      case PlaylistSortOption.titleAsc:
        return 'Titre (A → Z)';
      case PlaylistSortOption.artistAsc:
        return 'Artiste (A → Z)';
      case PlaylistSortOption.durationDesc:
        return 'Durée';
    }
  }

  void _showSortBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF141418),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    "Trier les morceaux",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ...PlaylistSortOption.values.map((option) {
                  final isSelected = _sortOption == option;
                  IconData icon;
                  switch (option) {
                    case PlaylistSortOption.custom:
                      icon = Icons.format_list_numbered_rounded;
                      break;
                    case PlaylistSortOption.recentFirst:
                      icon = Icons.schedule_rounded;
                      break;
                    case PlaylistSortOption.titleAsc:
                      icon = Icons.sort_by_alpha_rounded;
                      break;
                    case PlaylistSortOption.artistAsc:
                      icon = Icons.person_outline_rounded;
                      break;
                    case PlaylistSortOption.durationDesc:
                      icon = Icons.timer_outlined;
                      break;
                  }
                  return ListTile(
                    leading: Icon(
                      icon,
                      color: isSelected ? AppColors.primary : Colors.white70,
                    ),
                    title: Text(
                      _getSortLabel(option),
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : Colors.white,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() => _sortOption = option);
                      Navigator.pop(sheetCtx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPlaylistOptionsSheet(BuildContext context, PlaylistModel livePlaylist) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: const Color(0xFF141418),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      PlaylistCoverMosaic(
                        playlist: livePlaylist,
                        size: 50,
                        height: 52,
                        borderRadius: 10,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              livePlaylist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${livePlaylist.tracks.length} morceaux • ${_formatTotalDuration(livePlaylist.tracks)}",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 22),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                  title: const Text(
                    "Ajouter des titres",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showAddTracksBottomSheet(context, livePlaylist);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Colors.white),
                  title: const Text(
                    "Modifier le nom ou la pochette",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    PlaylistEditorSheet.show(context, existingPlaylist: livePlaylist);
                  },
                ),
                ListTile(
                  leading: Icon(
                    livePlaylist.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                    color: livePlaylist.isPinned ? AppColors.primary : Colors.white,
                  ),
                  title: Text(
                    livePlaylist.isPinned ? "Désépingler" : "Épingler en haut",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    context.read<LibraryCubit>().togglePinPlaylist(livePlaylist.id, livePlaylist.isPinned);
                  },
                ),
                if (livePlaylist.tracks.isNotEmpty) ...[
                  ListTile(
                    leading: const Icon(Icons.download_for_offline_outlined, color: Colors.white),
                    title: const Text(
                      "Télécharger hors-ligne",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _downloadAllPlaylistTracks(context, livePlaylist.tracks);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.checklist_rounded, color: Colors.white),
                    title: const Text(
                      "Sélectionner des titres",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      setState(() {
                        _isSelectionMode = true;
                        _selectedTrackIds.clear();
                      });
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text(
                    "Supprimer la playlist",
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _confirmDeletePlaylist(context, livePlaylist);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeletePlaylist(BuildContext context, PlaylistModel livePlaylist) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF16161B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Supprimer la playlist",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          "Voulez-vous vraiment supprimer « ${livePlaylist.name} » ?",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text("Annuler", style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              context.read<LibraryCubit>().deletePlaylist(livePlaylist.id);
              Navigator.pop(dialogCtx);
              Navigator.pop(context);
            },
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
  }

  void _downloadAllPlaylistTracks(BuildContext context, List<TrackModel> tracks) {
    if (tracks.isEmpty) return;
    final downloadCubit = context.read<DownloadCubit>();
    int addedCount = 0;
    final currentState = downloadCubit.state;
    final downloadedIds = currentState is DownloadStateData ? currentState.downloadedIds : <String>[];

    for (final track in tracks) {
      if (!downloadedIds.contains(track.id)) {
        downloadCubit.downloadTrack(track);
        addedCount++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1C1C22),
        behavior: SnackBarBehavior.floating,
        content: Text(
          addedCount > 0
              ? "Téléchargement lancé pour $addedCount morceau${addedCount > 1 ? 'x' : ''}..."
              : "Tous les morceaux sont déjà téléchargés !",
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _showAddTracksBottomSheet(BuildContext context, PlaylistModel livePlaylist) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<LibraryCubit>(),
        child: _AddTracksToPlaylistSheet(playlistId: livePlaylist.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, libraryState) {
        final libraryCubit = context.read<LibraryCubit>();
        final resolvedId = libraryCubit.resolvePlaylistId(widget.playlist.id);

        PlaylistModel livePlaylist = widget.playlist;
        if (libraryState is LibraryLoaded) {
          for (final p in libraryState.playlists) {
            if (p.id == widget.playlist.id || p.id == resolvedId) {
              livePlaylist = p;
              break;
            }
          }
        }

        final allTracks = livePlaylist.tracks;
        final displayedTracks = _getFilteredAndSortedTracks(allTracks);
        final topArtists = _extractTopArtists(allTracks);
        final String sourceLabel = "la playlist ${livePlaylist.name}";
        final String heroCoverUrl = _resolveHeroCoverUrl(livePlaylist);

        return Scaffold(
          backgroundColor: const Color(0xFF0C0C0E),
          body: SonoritizCoverAtmosphere(
            coverUrl: heroCoverUrl,
            child: Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    ValueListenableBuilder<double>(
                      valueListenable: _collapseProgress,
                      builder: (context, collapse, _) {
                        return SliverAppBar(
                          backgroundColor: const Color(0xFF0C0C0E).withValues(alpha: collapse * 0.90),
                          elevation: 0,
                          pinned: true,
                          toolbarHeight: 62,
                          leading: IconButton(
                            icon: Icon(
                              _isSelectionMode ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              if (_isSelectionMode) {
                                setState(() {
                                  _isSelectionMode = false;
                                  _selectedTrackIds.clear();
                                });
                              } else {
                                Navigator.pop(context);
                              }
                            },
                          ),
                          title: _isSelectionMode
                              ? Text(
                                  "${_selectedTrackIds.length} sélectionné${_selectedTrackIds.length > 1 ? 's' : ''}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                )
                              : IgnorePointer(
                                  ignoring: collapse < 0.2,
                                  child: Opacity(
                                    opacity: collapse,
                                    child: Row(
                                      children: [
                                        PlaylistCoverMosaic(
                                          playlist: livePlaylist,
                                          size: 32,
                                          height: 34,
                                          borderRadius: 6,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: SonoritizPageTitle(
                                              title: livePlaylist.name,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          actions: [
                            if (_isSelectionMode)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    if (_selectedTrackIds.length == displayedTracks.length) {
                                      _selectedTrackIds.clear();
                                    } else {
                                      _selectedTrackIds
                                        ..clear()
                                        ..addAll(displayedTracks.map((t) => t.id));
                                    }
                                  });
                                },
                                child: Text(
                                  _selectedTrackIds.length == displayedTracks.length
                                      ? "Tout désélect."
                                      : "Tout sélect.",
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else ...[
                              if (collapse > 0.72 && displayedTracks.isNotEmpty)
                                IconButton(
                                  tooltip: "Lire",
                                  onPressed: () {
                                    context.read<PlayerCubit>().playTrack(
                                          displayedTracks.first,
                                          queue: displayedTracks,
                                          source: sourceLabel,
                                        );
                                  },
                                  icon: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              if (allTracks.isNotEmpty)
                                IconButton(
                                  tooltip: "Rechercher dans la playlist",
                                  icon: Icon(
                                    _isSearching ? Icons.close_rounded : Icons.search_rounded,
                                    color: _isSearching ? AppColors.primary : Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isSearching = !_isSearching;
                                      if (!_isSearching) {
                                        _searchQuery = '';
                                        _searchController.clear();
                                      }
                                    });
                                  },
                                ),
                              IconButton(
                                tooltip: "Options de la playlist",
                                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                                onPressed: () => _showPlaylistOptionsSheet(context, livePlaylist),
                              ),
                            ],
                          ],
                        );
                      },
                    ),

                    // --- EN-TÊTE ÉDITORIAL SANS CADRE LOURD ---
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                        child: Column(
                          children: [
                            // Recherche repliable
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 220),
                              crossFadeState: _isSearching
                                  ? CrossFadeState.showFirst
                                  : CrossFadeState.showSecond,
                              firstChild: Padding(
                                padding: const EdgeInsets.only(bottom: 18, top: 4),
                                child: TextField(
                                  controller: _searchController,
                                  autofocus: _isSearching,
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: "Rechercher dans ${livePlaylist.name}...",
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.45),
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(
                                              Icons.clear_rounded,
                                              color: Colors.white.withValues(alpha: 0.6),
                                              size: 19,
                                            ),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.07),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              secondChild: const SizedBox.shrink(),
                            ),

                            // Triptyque 3 pochettes mis en valeur (proportions verticales préservées)
                            Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      blurRadius: 34,
                                      spreadRadius: -4,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: PlaylistCoverMosaic(
                                  playlist: livePlaylist,
                                  size: 214,
                                  height: 228,
                                  borderRadius: 18,
                                ),
                              ),
                            ).animate().fadeIn(duration: 280.ms).scale(
                                  begin: const Offset(0.96, 0.96),
                                  end: const Offset(1.0, 1.0),
                                  curve: Curves.easeOutCubic,
                                ),

                            const SizedBox(height: 20),

                            if (livePlaylist.isPinned)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.push_pin_rounded,
                                      color: AppColors.primary,
                                      size: 14,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      "ÉPINGLÉE",
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            Center(
                              child: SonoritizPageTitle(
                                title: livePlaylist.name,
                                fontSize: 29,
                                maxLines: 2,
                                centered: true,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              allTracks.isEmpty
                                  ? "Playlist vide"
                                  : "${allTracks.length} ${allTracks.length > 1 ? 'titres' : 'titre'} • ${_formatTotalDuration(allTracks)}",
                              style: TextStyle(
                                fontSize: 15.5,
                                color: Colors.white.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            if (topArtists.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                "${topArtists.take(3).map((e) => e.key).join(', ')}${topArtists.length > 3 ? '...' : ''}",
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.60),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],

                            // Barre d'actions épurée sur une seule ligne
                            if (allTracks.isNotEmpty) ...[
                              const SizedBox(height: 22),
                              BlocBuilder<PlayerCubit, PlayerState>(
                                builder: (context, playerState) {
                                  final bool isThisPlaylistPlaying = playerState.isPlaying &&
                                      playerState.currentTrack != null &&
                                      allTracks.any((t) => t.id == playerState.currentTrack!.id);

                                  return Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 48,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.black,
                                              elevation: 0,
                                              shape: const StadiumBorder(),
                                            ),
                                            onPressed: () {
                                              if (displayedTracks.isEmpty) return;
                                              final cubit = context.read<PlayerCubit>();
                                              if (isThisPlaylistPlaying) {
                                                cubit.togglePlayPause();
                                              } else {
                                                cubit.playTrack(
                                                  displayedTracks.first,
                                                  queue: displayedTracks,
                                                  source: sourceLabel,
                                                );
                                              }
                                            },
                                            icon: Icon(
                                              isThisPlaylistPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              size: 24,
                                            ),
                                            label: Text(
                                              isThisPlaylistPlaying ? "Pause" : "Lire",
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: SizedBox(
                                          height: 48,
                                          child: TextButton.icon(
                                            style: TextButton.styleFrom(
                                              backgroundColor: Colors.white.withValues(alpha: 0.10),
                                              foregroundColor: Colors.white,
                                              shape: const StadiumBorder(),
                                            ),
                                            onPressed: () {
                                              if (displayedTracks.isNotEmpty) {
                                                final shuffled = List<TrackModel>.from(displayedTracks)
                                                  ..shuffle();
                                                context.read<PlayerCubit>().playTrack(
                                                      shuffled.first,
                                                      queue: shuffled,
                                                      source: sourceLabel,
                                                    );
                                              }
                                            },
                                            icon: const Icon(Icons.shuffle_rounded, size: 20),
                                            label: const Text(
                                              "Aléatoire",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Tooltip(
                                        message: "Ajouter des titres",
                                        child: Material(
                                          color: Colors.white.withValues(alpha: 0.10),
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            customBorder: const CircleBorder(),
                                            onTap: () => _showAddTracksBottomSheet(context, livePlaylist),
                                            child: const SizedBox(
                                              width: 48,
                                              height: 48,
                                              child: Icon(
                                                Icons.add_rounded,
                                                color: Colors.white,
                                                size: 23,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],

                            // Filtres artistes légers sans bordure lourde
                            if (topArtists.length > 1) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 32,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: (topArtists.length > 10 ? 10 : topArtists.length) + 1,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      final isAllSelected = _selectedArtistFilter == null;
                                      return GestureDetector(
                                        onTap: () => setState(() => _selectedArtistFilter = null),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isAllSelected
                                                ? AppColors.primary
                                                : Colors.white.withValues(alpha: 0.07),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                            child: Text(
                                              "Tous",
                                              style: TextStyle(
                                                color: isAllSelected ? Colors.black : Colors.white,
                                                fontSize: 13.5,
                                                fontWeight: isAllSelected ? FontWeight.w700 : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        );
                                      }

                                      final artistEntry = topArtists[index - 1];
                                      final isSelected = _selectedArtistFilter?.toLowerCase() ==
                                          artistEntry.key.toLowerCase();

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedArtistFilter = isSelected ? null : artistEntry.key;
                                          });
                                        },
                                        onLongPress: () {
                                          context.push(
                                            '/artist',
                                            extra: {'name': artistEntry.key},
                                          );
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.white.withValues(alpha: 0.07),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            "${artistEntry.key} (${artistEntry.value})",
                                            style: TextStyle(
                                              color: isSelected ? Colors.black : Colors.white,
                                              fontSize: 13.5,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],

                            // Ligne discrète de tri & réinitialisation
                            if (allTracks.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    "${displayedTracks.length} titre${displayedTracks.length > 1 ? 's' : ''}",
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.72),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_selectedArtistFilter != null ||
                                      _searchQuery.isNotEmpty ||
                                      _sortOption != PlaylistSortOption.custom) ...[
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _sortOption = PlaylistSortOption.custom;
                                          _selectedArtistFilter = null;
                                          _searchQuery = '';
                                          _searchController.clear();
                                        });
                                      },
                                      child: const Text(
                                        "Réinitialiser",
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _showSortBottomSheet(context),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.swap_vert_rounded,
                                            size: 17,
                                            color: _sortOption != PlaylistSortOption.custom
                                                ? AppColors.primary
                                                : Colors.white.withValues(alpha: 0.75),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _getSortLabel(_sortOption),
                                            style: TextStyle(
                                              color: _sortOption != PlaylistSortOption.custom
                                                  ? AppColors.primary
                                                  : Colors.white.withValues(alpha: 0.75),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // --- LISTE DES MORCEAUX ÉPURÉE ---
                    if (allTracks.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.music_note_rounded,
                                  size: 40,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Aucun titre pour l'instant",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Ajoute tes morceaux préférés pour commencer.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 22),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  minimumSize: const Size(210, 48),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () => _showAddTracksBottomSheet(context, livePlaylist),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text(
                                  "Ajouter des titres",
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (displayedTracks.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 44,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Aucun titre ne correspond à votre filtre",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final track = displayedTracks[index];
                            return _buildRichTrackItem(
                              context: context,
                              track: track,
                              queue: displayedTracks,
                              index: index,
                              playlistId: livePlaylist.id,
                              sourceLabel: sourceLabel,
                            );
                          },
                          childCount: displayedTracks.length,
                        ),
                      ),

                    if (allTracks.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => _showAddTracksBottomSheet(context, livePlaylist),
                            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                            label: const Text(
                              "Ajouter d'autres titres",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Barre flottante mode Sélection Multiple
                if (_isSelectionMode && _selectedTrackIds.isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 96,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181E),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 44),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () {
                                final selectedTracks = allTracks
                                    .where((t) => _selectedTrackIds.contains(t.id))
                                    .toList();
                                _downloadAllPlaylistTracks(context, selectedTracks);
                                setState(() {
                                  _isSelectionMode = false;
                                  _selectedTrackIds.clear();
                                });
                              },
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text("Télécharger"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(0, 44),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () {
                                final cubit = context.read<LibraryCubit>();
                                for (final id in _selectedTrackIds) {
                                  cubit.removeTrackFromPlaylist(livePlaylist.id, id);
                                }
                                setState(() {
                                  _isSelectionMode = false;
                                  _selectedTrackIds.clear();
                                });
                              },
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text("Retirer"),
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
      },
    );
  }

  Widget _buildRichTrackItem({
    required BuildContext context,
    required TrackModel track,
    required List<TrackModel> queue,
    required int index,
    required int playlistId,
    required String sourceLabel,
  }) {
    return BlocSelector<PlayerCubit, PlayerState, bool>(
      selector: (state) => state.currentTrack?.id == track.id,
      builder: (context, isCurrentTrack) {
        final isSelected = _selectedTrackIds.contains(track.id);
        final durationStr = _formatTrackDuration(track.durationSeconds);

        final tileContent = Material(
          color: isCurrentTrack
              ? AppColors.primary.withValues(alpha: 0.09)
              : (isSelected ? Colors.white.withValues(alpha: 0.06) : Colors.transparent),
          child: InkWell(
            onTap: () {
              if (_isSelectionMode) {
                setState(() {
                  if (isSelected) {
                    _selectedTrackIds.remove(track.id);
                  } else {
                    _selectedTrackIds.add(track.id);
                  }
                });
              } else {
                context.read<PlayerCubit>().playTrack(
                      track,
                      queue: queue,
                      source: sourceLabel,
                    );
              }
            },
            onLongPress: () {
              if (!_isSelectionMode) {
                TrackContextMenu.show(context, track, playlistId: playlistId);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Center(
                      child: isCurrentTrack
                          ? const Icon(
                              Icons.graphic_eq_rounded,
                              color: AppColors.primary,
                              size: 18,
                            )
                          : Text(
                              "${index + 1}",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.52),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: PlayingIndicatorOverlay(
                        trackId: track.id,
                        child: track.coverUrl.isNotEmpty
                            ? (track.coverUrl.startsWith('file://') ||
                                    track.coverUrl.startsWith('http://local.image/')
                                ? Image.file(
                                    File(
                                      track.coverUrl
                                          .replaceFirst('file://', '')
                                          .replaceFirst('http://local.image/', ''),
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildFallbackCover(),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: track.coverUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => _buildFallbackCover(),
                                  ))
                            : _buildFallbackCover(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrentTrack ? AppColors.primary : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            BlocBuilder<DownloadCubit, DownloadState>(
                              builder: (context, dlState) {
                                final isDownloaded = dlState is DownloadStateData &&
                                    dlState.downloadedIds.contains(track.id);
                                if (!isDownloaded) return const SizedBox.shrink();
                                return const Padding(
                                  padding: EdgeInsets.only(right: 5),
                                  child: Icon(
                                    Icons.download_done_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                );
                              },
                            ),
                            Expanded(
                              child: ArtistNameDisplay(
                                artistName: track.artistName,
                                maxLines: 1,
                                style: TextStyle(
                                  color: isCurrentTrack
                                      ? AppColors.primary.withValues(alpha: 0.85)
                                      : Colors.white.withValues(alpha: 0.72),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_isSelectionMode)
                    Checkbox(
                      value: isSelected,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedTrackIds.add(track.id);
                          } else {
                            _selectedTrackIds.remove(track.id);
                          }
                        });
                      },
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (durationStr.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              durationStr,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.56),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        BlocBuilder<LibraryCubit, LibraryState>(
                          builder: (context, _) {
                            final isFav = context.read<LibraryCubit>().isFavorite(
                                  track.id,
                                  title: track.title,
                                  artist: track.artistName,
                                );
                            return IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: isFav ? AppColors.primary : Colors.white.withValues(alpha: 0.35),
                                size: 19,
                              ),
                              onPressed: () {
                                final libCubit = context.read<LibraryCubit>();
                                if (isFav) {
                                  libCubit.removeFavorite(track.id);
                                } else {
                                  libCubit.addFavorite(track);
                                }
                              },
                            );
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 20,
                          ),
                          onPressed: () => TrackContextMenu.show(
                            context,
                            track,
                            playlistId: playlistId,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );

        if (_isSelectionMode) return tileContent;

        return Dismissible(
          key: ValueKey('playlist_${playlistId}_track_${track.id}_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerRight,
            color: Colors.redAccent.withValues(alpha: 0.85),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Retirer",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.delete_outline_rounded, color: Colors.white),
              ],
            ),
          ),
          onDismissed: (_) {
            final libCubit = context.read<LibraryCubit>();
            libCubit.removeTrackFromPlaylist(playlistId, track.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF1C1C22),
                behavior: SnackBarBehavior.floating,
                content: Text(
                  "« ${track.title} » retiré de la playlist",
                  style: const TextStyle(color: Colors.white),
                ),
                action: SnackBarAction(
                  label: "Annuler",
                  textColor: AppColors.primary,
                  onPressed: () {
                    libCubit.addTrackToPlaylist(playlistId, track);
                  },
                ),
              ),
            );
          },
          child: tileContent,
        );
      },
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      color: const Color(0xFF1C1C22),
      child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 20),
    );
  }
}

class _AddTracksToPlaylistSheet extends StatefulWidget {
  final int playlistId;

  const _AddTracksToPlaylistSheet({required this.playlistId});

  @override
  State<_AddTracksToPlaylistSheet> createState() => _AddTracksToPlaylistSheetState();
}

class _AddTracksToPlaylistSheetState extends State<_AddTracksToPlaylistSheet> {
  final TextEditingController _queryController = TextEditingController();
  late final CatalogRepository _catalogRepository;
  Timer? _debounce;
  bool _isLoadingSearch = false;
  List<TrackModel> _searchResults = [];
  int _selectedTab = 0; // 0: Catalogue, 1: Favoris, 2: Récents

  @override
  void initState() {
    super.initState();
    _catalogRepository = CatalogRepository(
      apiClient: ApiClient(storageService: StorageService()),
    );
    _performSearch('Top Hits');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoadingSearch = true);
    try {
      final results = await _catalogRepository.searchTracks(query: query.trim(), limit: 25);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoadingSearch = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSearch = false);
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      if (val.trim().isNotEmpty) {
        _performSearch(val);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141418),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Ajouter des morceaux",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _queryController,
                  onChanged: (v) {
                    if (_selectedTab != 0) {
                      setState(() => _selectedTab = 0);
                    }
                    _onSearchChanged(v);
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Rechercher un son, un artiste...",
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildSourceTab(0, "Catalogue", Icons.explore_outlined),
                    const SizedBox(width: 8),
                    _buildSourceTab(1, "Favoris", Icons.favorite_border_rounded),
                    const SizedBox(width: 8),
                    _buildSourceTab(2, "Récents", Icons.history_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: BlocBuilder<LibraryCubit, LibraryState>(
                  builder: (context, libState) {
                    final resolvedId = context.read<LibraryCubit>().resolvePlaylistId(widget.playlistId);
                    Set<String> existingIds = {};
                    List<TrackModel> favorites = [];
                    List<TrackModel> recentTracks = [];

                    if (libState is LibraryLoaded) {
                      for (final p in libState.playlists) {
                        if (p.id == widget.playlistId || p.id == resolvedId) {
                          existingIds = p.tracks.map((e) => e.id).toSet();
                          break;
                        }
                      }
                      favorites = libState.favorites;
                      for (final h in libState.history) {
                        if (h.track != null && !recentTracks.any((t) => t.id == h.track!.id)) {
                          recentTracks.add(h.track!);
                        }
                      }
                    }

                    List<TrackModel> listToShow = _searchResults;
                    if (_selectedTab == 1) {
                      listToShow = favorites;
                    } else if (_selectedTab == 2) {
                      listToShow = recentTracks;
                    }

                    if (_selectedTab == 0 && _isLoadingSearch) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }

                    if (listToShow.isEmpty) {
                      return Center(
                        child: Text(
                          "Aucun morceau trouvé",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: listToShow.length,
                      itemBuilder: (context, index) {
                        final track = listToShow[index];
                        final alreadyAdded = existingIds.contains(track.id);

                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 46,
                              height: 46,
                              child: track.coverUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: track.coverUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: const Color(0xFF1C1C22),
                                        child: const Icon(Icons.music_note, color: Colors.white38),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFF1C1C22),
                                      child: const Icon(Icons.music_note, color: Colors.white38),
                                    ),
                            ),
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            track.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.56),
                              fontSize: 13,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              alreadyAdded
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              color: alreadyAdded ? AppColors.primary : Colors.white,
                              size: 26,
                            ),
                            onPressed: () {
                              final cubit = context.read<LibraryCubit>();
                              if (alreadyAdded) {
                                cubit.removeTrackFromPlaylist(widget.playlistId, track.id);
                              } else {
                                cubit.addTrackToPlaylist(widget.playlistId, track);
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceTab(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSelected ? Colors.black : Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
