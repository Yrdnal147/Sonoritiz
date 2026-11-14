import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/storage/storage_service.dart';
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
      floatingActionButton: _localTracks.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _pickAudioFiles,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: const Text("Ajouter"),
            ),
      body: _localTracks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.audio_file_rounded,
                          size: 46,
                          color: colorScheme.primary.withValues(alpha: 0.7)),
                    ).animate().scale(
                        delay: AppAnimations.normal,
                        duration: AppAnimations.slow,
                        curve: Curves.easeOutBack),
                    const SizedBox(height: 20),
                    Text(
                      "Aucun son interne",
                      style:
                          textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ).animate().fadeIn(delay: AppAnimations.slow),
                    const SizedBox(height: 8),
                    Text(
                      "Importe des musiques stockées sur ton téléphone.",
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ).animate().fadeIn(delay: AppAnimations.slow),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _pickAudioFiles,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text("Importer des sons"),
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
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
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Row(
                            children: [
                              Text(
                                '${sortedTracks.length} ${sortedTracks.length > 1 ? "fichiers locaux" : "fichier local"}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  final shuffled =
                                      List<TrackModel>.from(sortedTracks)
                                        ..shuffle();
                                  context
                                      .read<PlayerCubit>()
                                      .playTrack(shuffled.first, queue: shuffled);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.16),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.shuffle_rounded,
                                          color: Colors.white, size: 19),
                                      SizedBox(width: 6),
                                      Text(
                                        "Aléatoire",
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
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () {
                                  context.read<PlayerCubit>().playTrack(
                                        sortedTracks.first,
                                        queue: sortedTracks,
                                      );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_arrow_rounded,
                                          color: Colors.black, size: 21),
                                      SizedBox(width: 4),
                                      Text(
                                        "Lire",
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
      onTap: () => context.read<PlayerCubit>().playTrack(track, queue: queue),
      trailing: SonoritizIconButton(
        icon: Icons.delete_outline_rounded,
        tooltip: "Retirer",
        color: colorScheme.error,
        onPressed: () => _showRemoveDialog(track),
      ),
    );
  }
}
