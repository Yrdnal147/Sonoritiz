import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/widgets/track_context_menu.dart';
import '../../../core/widgets/track_grid_view.dart';
import '../../../core/widgets/sonoritiz_track_tile.dart';
import '../../../core/widgets/sonoritiz_icon_button.dart';
import '../../../core/widgets/sonoritiz_fast_scrollbar.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import 'cubit/library_ui_cubit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audiotags/audiotags.dart';
import 'package:path_provider/path_provider.dart';

class LocalAudioScreen extends StatefulWidget {
  final StorageService storageService;

  const LocalAudioScreen({Key? key, required this.storageService})
      : super(key: key);

  @override
  State<LocalAudioScreen> createState() => _LocalAudioScreenState();
}

class _LocalAudioScreenState extends State<LocalAudioScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static final Map<String, TrackModel> _trackCache = {};
  static String? _cachedDocDirPath;

  List<TrackModel> _localTracks = [];
  String? _docDirPath;

  @override
  void initState() {
    super.initState();
    _docDirPath = _cachedDocDirPath;
    if (_docDirPath != null) {
      final cachedTracks = widget.storageService
          .getLocalFiles()
          .map((p) => _trackCache[p])
          .whereType<TrackModel>()
          .toList();
      _localTracks = cachedTracks;
    }
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    if (_docDirPath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _docDirPath = dir.path;
      _cachedDocDirPath = dir.path;
    }
    _loadLocalTracks();
  }

  Future<void> _loadLocalTracks() async {
    if (_docDirPath == null) return;
    final paths = widget.storageService.getLocalFiles();
    final List<TrackModel> tracks = [];

    for (final String path in paths) {
      if (File(path).existsSync()) {
        final cached = _trackCache[path];
        if (cached != null) {
          tracks.add(cached);
        } else {
          final parsed = await _pathToTrackModel(path);
          _trackCache[path] = parsed;
          tracks.add(parsed);
        }
      }
    }

    if (mounted) {
      setState(() {
        _localTracks = tracks;
      });
    }
  }

  Future<TrackModel> _pathToTrackModel(String path) async {
    final id = "local_${path.hashCode}";
    final fileName = path.split(RegExp(r'[/\\]')).last;
    final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

    String artist = "Artiste inconnu";
    String title = nameWithoutExt;

    try {
      final tag = await AudioTags.read(path);
      if (tag != null) {
        if (tag.trackArtist != null && tag.trackArtist!.isNotEmpty) {
          artist = tag.trackArtist!;
        } else if (tag.albumArtist != null && tag.albumArtist!.isNotEmpty) {
          artist = tag.albumArtist!;
        }
        if (tag.title != null && tag.title!.isNotEmpty) {
          title = tag.title!;
        }
      }
    } catch (_) {}

    if (artist == "Artiste inconnu" && nameWithoutExt.contains('-')) {
      final parts = nameWithoutExt.split('-');
      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts.sublist(1).join('-').trim();
      }
    }

    String coverUrl = "";
    if (_docDirPath != null) {
      final possibleCoverPath = "$_docDirPath/cover_${path.hashCode}.jpg";
      if (File(possibleCoverPath).existsSync()) {
        coverUrl = "file://$possibleCoverPath";
      }
    }

    return TrackModel(
      id: id,
      title: title,
      artistName: artist,
      coverUrl: coverUrl,
      audioUrl: "file://$path",
      durationSeconds: 0,
    );
  }

  Future<void> _pickAudioFiles() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null) {
        final List<String> currentPaths =
            List<String>.from(widget.storageService.getLocalFiles());
        bool addedNew = false;

        for (final file in result.files) {
          if (file.path != null) {
            final fileName = file.path!.split(RegExp(r'[/\\]')).last;
            final persistentPath = '$_docDirPath/$fileName';

            if (!currentPaths.contains(persistentPath)) {
              try {
                final persistentFile =
                    await File(file.path!).copy(persistentPath);
                currentPaths.add(persistentFile.path);
                addedNew = true;
              } catch (e) {
                debugPrint("Failed to copy file to persistent storage: $e");
              }
            }
          }
        }

        if (addedNew) {
          await widget.storageService.saveLocalFiles(currentPaths);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Extraction des pochettes en cours...")),
            );
          }

          for (final file in result.files) {
            if (file.path != null) {
              try {
                final fileName = file.path!.split(RegExp(r'[/\\]')).last;
                final persistentPath = '$_docDirPath/$fileName';
                final persistentFile = File(persistentPath);

                final tag = await AudioTags.read(
                    persistentFile.existsSync() ? persistentPath : file.path!);
                final picture =
                    (tag?.pictures.isNotEmpty == true) ? tag?.pictures.first : null;
                final albumArt = picture?.bytes;
                if (albumArt != null &&
                    albumArt.isNotEmpty &&
                    _docDirPath != null) {
                  final coverPath =
                      '$_docDirPath/cover_${persistentPath.hashCode}.jpg';
                  final coverFile = File(coverPath);
                  if (!coverFile.existsSync()) {
                    await coverFile.writeAsBytes(albumArt);
                  }
                  _trackCache.remove(persistentPath);
                }
              } catch (e) {
                debugPrint("Failed to extract cover for ${file.path}: $e");
              }
            }
          }

          _loadLocalTracks();
        }
      }
    } catch (e) {
      debugPrint("Erreur lors de la sélection de fichiers : $e");
    }
  }

  void _removeLocalTrack(String pathToRemove) async {
    final paths = widget.storageService.getLocalFiles();
    paths.remove(pathToRemove);
    _trackCache.remove(pathToRemove);
    await widget.storageService.saveLocalFiles(paths);
    _loadLocalTracks();
  }

  void _showRemoveDialog(TrackModel track) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: const Text("Retirer"),
        content: Text("Retirer '${track.title}' de vos sons internes ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Annuler",
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError),
            onPressed: () {
              final path = track.audioUrl.replaceFirst("file://", "");
              _removeLocalTrack(path);
              Navigator.pop(ctx);
            },
            child: const Text("Retirer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _localTracks.isEmpty
          ? Center(
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
                        Icons.folder_special_rounded,
                        size: 42,
                        color: AppColors.primary,
                      ),
                    ).animate().scale(
                        delay: AppAnimations.normal,
                        duration: AppAnimations.slow,
                        curve: Curves.easeOutBack),
                    const SizedBox(height: 20),
                    Text(
                      "Aucun son interne",
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ).animate().fadeIn(delay: AppAnimations.slow),
                    const SizedBox(height: 8),
                    Text(
                      "Importe les musiques stockées sur ton téléphone pour les écouter dans Sonoritiz.",
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ).animate().fadeIn(delay: AppAnimations.slow),
                    const SizedBox(height: 26),
                    GestureDetector(
                      onTap: _pickAudioFiles,
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
                              Icons.add_rounded,
                              color: Colors.black,
                              size: 20,
                            ),
                            SizedBox(width: 7),
                            Text(
                              "Importer des sons",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: AppAnimations.slow),
                  ],
                ),
              ),
            )
          : BlocBuilder<LibraryUiCubit, LibraryUiState>(
              builder: (context, uiState) {
                final viewMode = uiState.getViewModeFor('local');
                final sortMode = uiState.getSortModeFor('local');
                final normalizedQuery =
                    LibraryUiCubit.normalizeForSearch(uiState.searchQuery);

                final filtered = normalizedQuery.isEmpty
                    ? _localTracks
                    : _localTracks.where((t) {
                        return LibraryUiCubit.normalizeForSearch(t.title)
                                .contains(normalizedQuery) ||
                            LibraryUiCubit.normalizeForSearch(t.artistName)
                                .contains(normalizedQuery);
                      }).toList();

                if (normalizedQuery.isNotEmpty && filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 46,
                              color: colorScheme.primary.withValues(alpha: 0.8)),
                          const SizedBox(height: 16),
                          Text(
                            "Aucun son local pour « ${uiState.searchQuery.trim()} »",
                            textAlign: TextAlign.center,
                            style: textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: () =>
                                context.read<LibraryUiCubit>().closeSearch(),
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            label: const Text("Effacer la recherche"),
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final sortedTracks = TrackGridView.sortTracks(filtered, sortMode);

                return SonoritizFastScrollbar(
                  itemCount: sortedTracks.length,
                  bottomMargin: 130,
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
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14141B),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
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
                                        '${sortedTracks.length} ${sortedTracks.length > 1 ? "sons locaux" : "son local"}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.2,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      GestureDetector(
                                        onTap: _pickAudioFiles,
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.add_circle_outline_rounded,
                                              color: AppColors.primary,
                                              size: 13.5,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              "Importer d'autres fichiers",
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    final shuffled =
                                        List<TrackModel>.from(sortedTracks)
                                          ..shuffle();
                                    context.read<PlayerCubit>().playTrack(
                                          shuffled.first,
                                          queue: shuffled,
                                          source: 'vos sons internes',
                                        );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(22),
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
                                          size: 17,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          "Aléatoire",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    context.read<PlayerCubit>().playTrack(
                                          sortedTracks.first,
                                          queue: sortedTracks,
                                          source: 'vos sons internes',
                                        );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.black,
                                          size: 19,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "Lire",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 13.5,
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
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      if (viewMode == ViewMode.list)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildListItem(
                              context,
                              sortedTracks[index],
                              sortedTracks,
                            ),
                            childCount: sortedTracks.length,
                          ),
                        )
                      else
                        TrackGridView(
                          key: ValueKey('${viewMode.name}_${sortMode.name}'),
                          tracks: filtered,
                          viewMode: viewMode,
                          sortMode: sortMode,
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildListItem(
      BuildContext context, TrackModel track, List<TrackModel> queue) {
    final colorScheme = Theme.of(context).colorScheme;

    return SonoritizTrackTile(
      track: track,
      queue: queue,
      playbackSource: 'vos sons internes',
      onTap: () => context
          .read<PlayerCubit>()
          .playTrack(track, queue: queue, source: 'vos sons internes'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SonoritizIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: "Options",
            color: Colors.white54,
            onPressed: () => TrackContextMenu.show(context, track),
          ),
          SonoritizIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: "Retirer",
            color: colorScheme.error,
            onPressed: () => _showRemoveDialog(track),
          ),
        ],
      ),
    );
  }
}
