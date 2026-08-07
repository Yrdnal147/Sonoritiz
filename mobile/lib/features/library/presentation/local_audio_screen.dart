import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/widgets/track_grid_view.dart';
import '../../player/data/models/track_model.dart';
import '../../player/presentation/cubit/player_cubit.dart';
import 'cubit/library_ui_cubit.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
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

  void _loadLocalTracks() {
    if (_docDirPath == null) return;
    final paths = widget.storageService.getLocalFiles();
    final List<TrackModel> tracks = [];
    
    for (String path in paths) {
      if (File(path).existsSync()) {
        tracks.add(_pathToTrackModel(path));
      }
    }
    
    setState(() {
      _localTracks = tracks;
    });
  }

  TrackModel _pathToTrackModel(String path) {
    // Generate a local ID
    final id = "local_${path.hashCode}";
    
    // Extract filename without extension
    final fileName = path.split('/').last;
    final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    
    // Try to guess artist and title (e.g. "Artist - Title")
    String artist = "Artiste inconnu";
    String title = nameWithoutExt;
    
    if (nameWithoutExt.contains('-')) {
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
      audioUrl: "file://$path", // Prefix with file:// for just_audio
      durationSeconds: 0, // Duration will be extracted by just_audio
    );
  }

  Future<void> _pickAudioFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null) {
        final List<String> currentPaths = widget.storageService.getLocalFiles();
        bool addedNew = false;
        
        for (var file in result.files) {
          if (file.path != null && !currentPaths.contains(file.path!)) {
            currentPaths.add(file.path!);
            addedNew = true;
          }
        }
        
        if (addedNew) {
          await widget.storageService.saveLocalFiles(currentPaths);
          
          // Show a temporary loading indicator
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Extraction des pochettes en cours...")));
          }
          
          // Extract covers for all new files
          for (var file in result.files) {
            if (file.path != null) {
              try {
                final metadata = await MetadataRetriever.fromFile(File(file.path!));
                final albumArt = metadata.albumArt;
                if (albumArt != null && albumArt.isNotEmpty && _docDirPath != null) {
                  final coverPath = '$_docDirPath/cover_${file.path!.hashCode}.jpg';
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Retirer", style: TextStyle(color: Colors.white)),
        content: Text("Retirer '${track.title}' de vos sons internes ?", style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              // Extract original path from file://...
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
    return Scaffold(
      backgroundColor: Colors.transparent, // background de LibraryScreen
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAudioFiles,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Ajouter des sons", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _localTracks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.audio_file_rounded, size: 64, color: Colors.white54),
                  ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 24),
                  const Text(
                    "Aucun son interne",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 8),
                  Text(
                    "Ajoute tes musiques depuis ton téléphone",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
                  ).animate().fadeIn(delay: 500.ms),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _pickAudioFiles,
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    label: const Text("Importer des sons"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
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
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Sons internes", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text("${_localTracks.length} titres", style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
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
                      // Let's use TrackGridView for grids
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: track.coverUrl.isNotEmpty && track.coverUrl.startsWith('file://')
            ? Image.file(
                File(track.coverUrl.replaceFirst('file://', '')),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 50,
                  height: 50,
                  color: AppColors.surfaceLight,
                  child: const Icon(Icons.music_note, color: AppColors.textSecondary),
                ),
              )
            : Container(
                width: 50,
                height: 50,
                color: AppColors.surfaceLight,
                child: const Icon(Icons.music_note, color: AppColors.textSecondary),
              ),
      ),
      title: Text(track.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(track.artistName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: AppColors.error),
        onPressed: () => _showRemoveDialog(track),
      ),
      onTap: () => context.read<PlayerCubit>().playTrack(track, queue: _localTracks),
    );
  }
}
