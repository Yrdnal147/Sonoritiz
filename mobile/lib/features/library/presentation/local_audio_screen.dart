import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/widgets/track_grid_view.dart';
import '../../../core/widgets/sonoritiz_track_tile.dart';
import '../../../core/widgets/sonoritiz_icon_button.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import 'cubit/library_ui_cubit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audiotags/audiotags.dart';
import 'package:path_provider/path_provider.dart';

class LocalAudioScreen extends StatefulWidget {
  final StorageService storageService;

  const LocalAudioScreen({Key? key, required this.storageService}) : super(key: key);

  @override
  State<LocalAudioScreen> createState() => _LocalAudioScreenState();
}

class _LocalAudioScreenState extends State<LocalAudioScreen> {
  List<TrackModel> _localTracks = [];
  String? _docDirPath;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final dir = await getApplicationDocumentsDirectory();
    _docDirPath = dir.path;
    _loadLocalTracks();
  }

  Future<void> _loadLocalTracks() async {
    if (_docDirPath == null) return;
    final paths = widget.storageService.getLocalFiles();
    final List<TrackModel> tracks = [];
    
    for (String path in paths) {
      if (File(path).existsSync()) {
        tracks.add(await _pathToTrackModel(path));
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
    final fileName = path.split('/').last;
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
    } catch (e) {
      // Ignorer l'erreur
    }
    
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
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null) {
        final List<String> currentPaths = List<String>.from(widget.storageService.getLocalFiles());
        bool addedNew = false;
        
        for (var file in result.files) {
          if (file.path != null) {
            final fileName = file.path!.split('/').last;
            final persistentPath = '$_docDirPath/$fileName';
            
            if (!currentPaths.contains(persistentPath)) {
              try {
                final persistentFile = await File(file.path!).copy(persistentPath);
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Extraction des pochettes en cours...")));
          }
          
          for (var file in result.files) {
            if (file.path != null) {
              try {
                final persistentPath = '$_docDirPath/${file.path!.split('/').last}';
                final persistentFile = File(persistentPath);
                
                final tag = await AudioTags.read(persistentFile.existsSync() ? persistentPath : file.path!);
                final picture = (tag?.pictures.isNotEmpty == true) ? tag?.pictures.first : null;
                final albumArt = picture?.bytes;
                if (albumArt != null && albumArt.isNotEmpty && _docDirPath != null) {
                  final coverPath = '$_docDirPath/cover_${persistentPath.hashCode}.jpg';
                  final coverFile = File(coverPath);
                  if (!coverFile.existsSync()) {
                    await coverFile.writeAsBytes(albumArt);
                  }
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
            child: Text("Annuler", style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAudioFiles,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Ajouter des sons"),
      ),
      body: _localTracks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spacingXl),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.audio_file_rounded, size: 64, color: colorScheme.onSurfaceVariant),
                  ).animate().scale(delay: AppAnimations.normal, duration: AppAnimations.slow, curve: Curves.easeOutBack),
                  const SizedBox(height: AppDimensions.spacingXl),
                  Text(
                    "Aucun son interne",
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ).animate().fadeIn(delay: AppAnimations.slow),
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    "Ajoute tes musiques depuis ton téléphone",
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ).animate().fadeIn(delay: AppAnimations.slow),
                  const SizedBox(height: AppDimensions.spacingXl),
                  ElevatedButton.icon(
                    onPressed: _pickAudioFiles,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    label: const Text("Importer des sons"),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
                ],
              ),
            )
          : BlocBuilder<LibraryUiCubit, LibraryUiState>(
              builder: (context, uiState) {
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppDimensions.spacingLg, AppDimensions.spacingXl, AppDimensions.spacingLg, AppDimensions.spacingMd),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Sons internes", style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            Text("${_localTracks.length} titres", style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                          ],
                        ).animate().fadeIn(),
                      ),
                    ),
                    if (uiState.getViewModeFor('local') == ViewMode.list)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildListItem(context, _localTracks[index], index),
                          childCount: _localTracks.length,
                        ),
                      )
                    else
                      TrackGridView(
                        tracks: _localTracks,
                        viewMode: uiState.getViewModeFor('local'),
                        sortMode: uiState.getSortModeFor('local'),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildListItem(BuildContext context, TrackModel track, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    return SonoritizTrackTile(
      imageUrl: track.coverUrl,
      title: track.title,
      subtitle: track.artistName,
      onTap: () => context.read<PlayerCubit>().playTrack(track, queue: _localTracks),
      trailing: SonoritizIconButton(
        icon: Icons.delete_outline_rounded,
        tooltip: "Retirer",
        color: colorScheme.error,
        onPressed: () => _showRemoveDialog(track),
      ),
    );
  }
}
