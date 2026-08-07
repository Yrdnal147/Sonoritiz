import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../core/utils/responsive_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../cubit/player_cubit.dart';
import '../cubit/player_state.dart';
import '../widgets/queue_bottom_sheet.dart';
import '../../data/models/track_model.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'lyrics_screen.dart';
import '../../../../features/library/presentation/cubit/library_cubit.dart';
import '../../../../features/library/presentation/cubit/library_state.dart';
import '../../../../features/offline/presentation/cubit/download_cubit.dart';
import '../../../../core/utils/share_utils.dart';

class FullscreenPlayerScreen extends StatefulWidget {
  const FullscreenPlayerScreen({Key? key}) : super(key: key);

  @override
  State<FullscreenPlayerScreen> createState() => _FullscreenPlayerScreenState();
}

class _FullscreenPlayerScreenState extends State<FullscreenPlayerScreen> {
  double _dragOffsetY = 0.0;
  Color? _dominantColor;
  String? _lastCoverUrl;
  bool _isVideoMode = false;
  bool _isVideoLoading = false;
  VideoPlayerController? _videoController;
  final YoutubeExplode _yt = YoutubeExplode();

  @override
  void initState() {
    super.initState();
    final track = context.read<PlayerCubit>().state.currentTrack;
    if (track != null && track.coverUrl.isNotEmpty) {
      _updateDominantColor(track.coverUrl);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _yt.close();
    super.dispose();
  }

  Future<void> _toggleVideoMode(Duration currentPosition) async {
    if (_isVideoLoading) return;

    final cubit = context.read<PlayerCubit>();
    final track = cubit.state.currentTrack;
    if (track == null) return;

    setState(() {
      _isVideoMode = !_isVideoMode;
    });

    if (_isVideoMode) {
      setState(() { _isVideoLoading = true; });
      try {
        await cubit.pause();
        
        String youtubeId = track.id;
        
        // If it's a local track, search YouTube to find a video
        if (track.id.startsWith('local_')) {
          final query = "${track.artistName} ${track.title} official video";
          final searchResults = await _yt.search.search(query);
          if (searchResults.isNotEmpty) {
            youtubeId = searchResults.first.id.value;
          } else {
            throw Exception("Aucune vidéo trouvée pour ce son.");
          }
        }
        
        final manifest = await _yt.videos.streamsClient.getManifest(youtubeId);
        final muxed = manifest.muxed;
        
        if (muxed.isNotEmpty) {
          final streamInfo = muxed.withHighestBitrate();
          _videoController = VideoPlayerController.networkUrl(streamInfo.url);
          _videoController!.addListener(() {
            if (mounted) setState(() {});
          });
          
          await _videoController!.initialize();
          await _videoController!.seekTo(currentPosition);
          
          if (mounted && _isVideoMode) {
            setState(() {}); 
            _videoController!.play();
          }
        } else {
          throw Exception("Aucun flux vidéo disponible");
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Vidéo indisponible, retour à l'audio.")),
          );
          setState(() {
            _isVideoMode = false;
          });
          cubit.play();
        }
      } finally {
        if (mounted) {
          setState(() { _isVideoLoading = false; });
        }
      }
    } else {
      if (_videoController != null) {
        final videoPosition = _videoController!.value.position;
        _videoController!.pause();
        _videoController!.dispose();
        _videoController = null;
        
        await cubit.seek(videoPosition);
        await cubit.play();
      }
    }
  }

  Future<void> _updateDominantColor(String coverUrl) async {
    if (_lastCoverUrl == coverUrl) return;
    _lastCoverUrl = coverUrl;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(coverUrl),
      );
      if (mounted) {
        setState(() {
          _dominantColor = palette.dominantColor?.color ?? palette.vibrantColor?.color;
        });
      }
    } catch (_) {}
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return minutes + ':' + seconds;
  }



  void _showAddToPlaylistSheet(BuildContext parentContext, TrackModel track) {
    final libraryCubit = parentContext.read<LibraryCubit>();
    showModalBottomSheet(
      context: parentContext,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return BlocProvider.value(
          value: libraryCubit,
          child: BlocBuilder<LibraryCubit, LibraryState>(
            builder: (ctx, state) {
              if (state is LibraryLoaded) {
                final playlists = state.playlists;
                if (playlists.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.playlist_add, size: 48, color: Colors.white38),
                        SizedBox(height: 12),
                        Text("Aucune playlist disponible.\nCrée-en une dans ta bibliothèque.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("Ajouter à la playlist", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(
                      height: (playlists.length * 56.0).clamp(56.0, 300.0),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = playlists[index];
                          return ListTile(
                            leading: const Icon(Icons.queue_music, color: AppColors.primary),
                            title: Text(playlist.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text("${playlist.tracksCount} morceaux", style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            onTap: () {
                              libraryCubit.addTrackToPlaylist(playlist.id, track);
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                SnackBar(
                                  content: Text("✓ Ajouté à ${playlist.name}", style: const TextStyle(color: Colors.white)),
                                  backgroundColor: AppColors.primary.withOpacity(0.9),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
            },
          ),
        );
      },
    );
  }

  Widget _buildGlassCircleButton({required IconData icon, required VoidCallback onTap, Color iconColor = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final dismissThreshold = screenHeight * 0.2;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! > 0) {
          setState(() {
            _dragOffsetY += details.primaryDelta!;
          });
        }
      },
      onVerticalDragEnd: (details) {
        if (_dragOffsetY > dismissThreshold) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _dragOffsetY = 0.0;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(0, _dragOffsetY, 0),
        decoration: BoxDecoration(
          color: const Color(0xFF121212).withOpacity((1 - (_dragOffsetY / screenHeight)).clamp(0.2, 1.0)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: BlocListener<PlayerCubit, PlayerState>(
              listenWhen: (previous, current) => previous.currentTrack?.id != current.currentTrack?.id,
              listener: (context, state) {
                if (_isVideoMode) {
                  setState(() {
                    _isVideoMode = false;
                    _videoController?.dispose();
                    _videoController = null;
                  });
                }
                final url = state.currentTrack?.coverUrl;
                if (url != null && url.isNotEmpty) {
                  _updateDominantColor(url);
                }
              },
              child: Stack(
                children: [
                  // --- ARRIÈRE-PLAN DÉGRADÉ DYNAMIQUE ---
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _dominantColor?.withOpacity(0.8) ?? AppColors.primary.withOpacity(0.5),
                          _dominantColor?.withOpacity(0.2) ?? const Color(0xFF121212),
                          Colors.black,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),

                  // --- CONTENU PRINCIPAL ---
                  SafeArea(
                    child: BlocBuilder<PlayerCubit, PlayerState>(
                      builder: (context, state) {
                        if (!state.hasTrack) {
                          return const Center(child: Text("Aucun morceau", style: TextStyle(color: Colors.white)));
                        }

                        final track = state.currentTrack!;
                        
                        // Variables dynamiques selon le mode (Audio ou Vidéo)
                        final isPlaying = _isVideoMode && _videoController != null 
                            ? _videoController!.value.isPlaying 
                            : state.isPlaying;
                            
                        final position = _isVideoMode && _videoController != null 
                            ? _videoController!.value.position 
                            : state.position;
                            
                        final duration = _isVideoMode && _videoController != null && _videoController!.value.duration.inMilliseconds > 0
                            ? _videoController!.value.duration 
                            : state.duration;

                        final isDesktop = ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isTablet(context);
                        final double coverSize = isDesktop 
                            ? math.min(screenWidth / 2 - 64, screenHeight * 0.6) 
                            : screenWidth - 32;

                        final appBar = // --- APP BAR (Top) ---
                            Padding(
                              padding: const EdgeInsets.only(top: 40.0, bottom: 16.0, left: 24.0, right: 24.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildGlassCircleButton(
                                    icon: Icons.keyboard_arrow_down_rounded,
                                    onTap: () => Navigator.pop(context),
                                  ),
                                  const Text(
                                    "En cours de lecture",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _buildGlassCircleButton(
                                        icon: Icons.playlist_add,
                                        onTap: () => _showAddToPlaylistSheet(context, track),
                                      ),
                                      BlocBuilder<LibraryCubit, LibraryState>(
                                        builder: (context, libraryState) {
                                          final isFav = context.read<LibraryCubit>().isFavorite(track.id);
                                          return _buildGlassCircleButton(
                                            icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            iconColor: isFav ? AppColors.primary : Colors.white,
                                            onTap: () {
                                              if (isFav) {
                                                context.read<LibraryCubit>().removeFavorite(track.id);
                                              } else {
                                                context.read<LibraryCubit>().addFavorite(track);
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);



                        final coverArt = 
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: CustomPaint(
                                foregroundPainter: RectangularProgressPainter(
                                  progress: duration.inMilliseconds > 0 
                                      ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0) 
                                      : 0.0,
                                  color: AppColors.primary,
                                  strokeWidth: 4.0,
                                  borderRadius: 32.0,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: _isVideoMode
                                      ? Container(
                                          width: coverSize,
                                          height: (coverSize) * 1.05,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(24),
                                            color: Colors.black, // Fond noir pendant le chargement
                                            boxShadow: [
                                              BoxShadow(
                                                color: (_dominantColor ?? AppColors.primary).withOpacity(0.4),
                                                blurRadius: 40,
                                                spreadRadius: 4,
                                                offset: const Offset(0, 15),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(24),
                                            child: _isVideoLoading || _videoController == null || !_videoController!.value.isInitialized
                                                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                                                : FittedBox(
                                                    fit: BoxFit.contain,
                                                    child: SizedBox(
                                                      width: _videoController!.value.size.width,
                                                      height: _videoController!.value.size.height,
                                                      child: VideoPlayer(_videoController!),
                                                    ),
                                                  ),
                                          ),
                                        ).animate().fadeIn()
                                      : Hero(
                                          tag: 'cover_' + track.id,
                                          child: Container(
                                            width: (coverSize - 16),
                                            height: ((coverSize - 16)) * 1.05, 
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(24),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (_dominantColor ?? AppColors.primary).withOpacity(0.4),
                                                  blurRadius: 40,
                                                  spreadRadius: 4,
                                                  offset: const Offset(0, 15),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(24),
                                              child: track.coverUrl.isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: track.coverUrl,
                                                      fit: BoxFit.cover,
                                                      errorWidget: (context, url, error) => Container(color: AppColors.surfaceLight),
                                                    )
                                                  : Container(color: AppColors.surfaceLight),
                                            ),
                                          ),
                                        ).animate().fadeIn(duration: 500.ms).scaleXY(begin: 0.9, end: 1.0),
                                ),
                              ).animate().fadeIn(duration: 600.ms),
                            );



                        final info = 
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Column(
                                children: [
                                  Text(
                                    track.title,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                                  const SizedBox(height: 4),
                                  Text(
                                    track.artistName,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                                ],
                              ),
                            );



                        final sliderWidget = 
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0), // Jauge plus courte
                              child: Column(
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: Colors.white,
                                      inactiveTrackColor: Colors.white.withOpacity(0.3),
                                      thumbColor: Colors.white,
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                    ),
                                    child: Slider(
                                      value: duration.inMilliseconds > 0
                                          ? position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble())
                                          : 0.0,
                                      max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0,
                                      onChanged: (val) {
                                        final newPosition = Duration(milliseconds: val.toInt());
                                        if (_isVideoMode && _videoController != null) {
                                          _videoController!.seekTo(newPosition);
                                        } else {
                                          context.read<PlayerCubit>().seek(newPosition);
                                        }
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatDuration(position), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                                        Text(_formatDuration(duration), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );



                        final mainControls = 
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.shuffle,
                                    color: state.isShuffleModeEnabled ? AppColors.primary : Colors.white.withOpacity(0.5),
                                    size: 26,
                                  ),
                                  onPressed: () => context.read<PlayerCubit>().toggleShuffle(),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
                                  onPressed: () => context.read<PlayerCubit>().playPrevious(),
                                ),
                                const SizedBox(width: 16),
                                GestureDetector(
                                  onTap: () {
                                    if (_isVideoMode && _videoController != null) {
                                      if (_videoController!.value.isPlaying) {
                                        _videoController!.pause();
                                      } else {
                                        _videoController!.play();
                                      }
                                    } else {
                                      context.read<PlayerCubit>().togglePlayPause();
                                    }
                                  },
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: _dominantColor ?? Colors.black87,
                                      size: 36,
                                    ),
                                  ).animate(target: isPlaying ? 1 : 0).scaleXY(begin: 1.0, end: 1.05, duration: 200.ms),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
                                  onPressed: () => context.read<PlayerCubit>().playNext(),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    state.loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                                    color: state.loopMode != LoopMode.off ? AppColors.primary : Colors.white.withOpacity(0.5),
                                    size: 26,
                                  ),
                                  onPressed: () => context.read<PlayerCubit>().toggleRepeat(),
                                ),
                              ],
                              ),
                            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0);

                        final sideActions = 
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.lyrics_outlined, color: Colors.white, size: 26),
                                    tooltip: "Paroles",
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BlocProvider.value(
                                            value: context.read<PlayerCubit>(),
                                            child: const LyricsScreen(),
                                          ),
                                        ),
                                      );
                                    },
                                  ).animate().fadeIn(delay: 400.ms),
                                  IconButton(
                                    icon: Icon(_isVideoMode ? Icons.audiotrack_outlined : Icons.videocam_outlined, color: Colors.white, size: 28),
                                    tooltip: _isVideoMode ? "Passer en mode audio" : "Passer en mode vidéo",
                                    onPressed: () => _toggleVideoMode(position),
                                  ).animate().fadeIn(delay: 400.ms),
                                  IconButton(
                                    icon: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 28),
                                    tooltip: "File d'attente",
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        backgroundColor: Colors.transparent,
                                        isScrollControlled: true,
                                        builder: (_) => BlocProvider.value(
                                          value: context.read<PlayerCubit>(),
                                          child: const QueueBottomSheet(),
                                        ),
                                      );
                                    },
                                  ).animate().fadeIn(delay: 400.ms),
                                  IconButton(
                                    icon: const Icon(Icons.share_rounded, color: Colors.white, size: 26),
                                    tooltip: "Partager",
                                    onPressed: () {
                                      ShareUtils.shareTrack(track);
                                    },
                                  ).animate().fadeIn(delay: 400.ms),
                                  BlocBuilder<DownloadCubit, DownloadState>(
                                    builder: (context, downloadState) {
                                      bool isDownloaded = false;
                                      bool isDownloading = false;
                                      double progress = 0.0;
                                      
                                      if (downloadState is DownloadStateData) {
                                        isDownloaded = downloadState.downloadedIds.contains(track.id);
                                        if (downloadState.downloadingProgress.containsKey(track.id)) {
                                          isDownloading = true;
                                          progress = downloadState.downloadingProgress[track.id]!;
                                        }
                                      }

                                      if (isDownloading) {
                                        return Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: SizedBox(
                                            width: 24, height: 24,
                                            child: CircularProgressIndicator(value: progress, color: AppColors.primary, strokeWidth: 3),
                                          ),
                                        );
                                      }

                                      return IconButton(
                                        icon: Icon(
                                          isDownloaded ? Icons.download_done : Icons.download_outlined,
                                          color: isDownloaded ? AppColors.primary : Colors.white,
                                          size: 28,
                                        ),
                                        tooltip: isDownloaded ? "Téléchargé" : "Télécharger",
                                        onPressed: () {
                                          if (isDownloaded) {
                                            context.read<DownloadCubit>().removeDownload(track.id);
                                          } else {
                                            context.read<DownloadCubit>().downloadTrack(track);
                                          }
                                        },
                                      ).animate().fadeIn(delay: 400.ms);
                                    },
                                  ),
                                ],
                              ),
                            );



                        if (isDesktop) {
                          return Column(
                            children: [
                              appBar,
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Center(child: coverArt),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              info,
                                              const SizedBox(height: 32),
                                              sliderWidget,
                                              const SizedBox(height: 24),
                                              mainControls,
                                              const SizedBox(height: 32),
                                              sideActions,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            appBar,
                            const SizedBox(height: 16),
                            coverArt,
                            const SizedBox(height: 24),
                            info,
                            const SizedBox(height: 24),
                            sliderWidget,
                            const Spacer(),
                            mainControls,
                            const Spacer(),
                            sideActions,
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RectangularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final double borderRadius;

  RectangularProgressPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 4.0,
    this.borderRadius = 32.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0) return;

    final rect = Rect.fromLTWH(
      strokeWidth / 2, 
      strokeWidth / 2, 
      size.width - strokeWidth, 
      size.height - strokeWidth
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final path = Path()..addRRect(rrect);
    
    // Piste de fond
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(path, trackPaint);

    if (progress > 0) {
      final pathMetrics = path.computeMetrics().toList();
      if (pathMetrics.isNotEmpty) {
        final metric = pathMetrics.first;
        final extractPath = metric.extractPath(0.0, metric.length * progress);
        
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawPath(extractPath, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RectangularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
