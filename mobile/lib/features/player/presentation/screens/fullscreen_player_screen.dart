import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../core/utils/responsive_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../core/widgets/sonoritiz_icon_button.dart';
import '../../../../core/utils/share_utils.dart';

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

import '../widgets/player_components/player_artwork_carousel.dart';
import '../widgets/player_components/player_track_info.dart';
import '../widgets/player_components/player_progress_bar.dart';
import '../widgets/player_components/player_primary_controls.dart';
import '../widgets/player_components/player_secondary_controls.dart';

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
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    final state = context.read<PlayerCubit>().state;
    _pageController = PageController(initialPage: state.currentIndex >= 0 ? state.currentIndex : 0, viewportFraction: 0.85);
    final track = state.currentTrack;
    if (track != null && track.coverUrl.isNotEmpty) {
      _updateDominantColor(track.coverUrl);
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _videoController?.dispose();
    _yt.close();
    super.dispose();
  }

  Future<void> _toggleVideoMode(Duration currentPosition) async {
    if (_isVideoLoading) return;
    final cubit = context.read<PlayerCubit>();
    final track = cubit.state.currentTrack;
    if (track == null) return;

    setState(() { _isVideoMode = !_isVideoMode; });

    if (_isVideoMode) {
      setState(() { _isVideoLoading = true; });
      try {
        await cubit.pause();
        String youtubeId = track.id;
        
        if (track.id.startsWith('local_')) {
          final query = "${track.artistName} ${track.title} official video";
          final searchResults = await _yt.search.search(query);
          if (searchResults.isNotEmpty) {
            youtubeId = searchResults.first.id.value;
          } else {
            throw Exception("Aucune vidéo trouvée");
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
          throw Exception("Aucun flux vidéo");
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Vidéo indisponible, retour à l'audio.")),
          );
          setState(() { _isVideoMode = false; });
          cubit.play();
        }
      } finally {
        if (mounted) setState(() { _isVideoLoading = false; });
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
      ImageProvider imageProvider;
      if (coverUrl.startsWith("file://")) {
        final path = coverUrl.replaceFirst("file://", "");
        if (File(path).existsSync()) {
          imageProvider = FileImage(File(path));
        } else {
          return;
        }
      } else {
        imageProvider = CachedNetworkImageProvider(coverUrl);
      }
      
      final palette = await PaletteGenerator.fromImageProvider(imageProvider);
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
    return '$minutes:$seconds';
  }

  void _showMoreOptionsBottomSheet(BuildContext context, TrackModel track) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: AppDimensions.spacingMd),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
              ),
              ListTile(
                leading: Icon(_isVideoMode ? Icons.audiotrack_outlined : Icons.videocam_outlined),
                title: Text(_isVideoMode ? "Passer en mode audio" : "Passer en mode vidéo"),
                onTap: () {
                  Navigator.pop(context);
                  _toggleVideoMode(context.read<PlayerCubit>().state.position);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text("Ajouter à la playlist"),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistSheet(context, track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text("Minuteur de sommeil"),
                onTap: () {
                  Navigator.pop(context);
                  _showSleepTimerBottomSheet(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text("Partager"),
                onTap: () {
                  Navigator.pop(context);
                  ShareUtils.shareTrack(track);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSleepTimerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return BlocProvider.value(
          value: context.read<PlayerCubit>(),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(AppDimensions.spacingLg),
                  child: Text("Minuteur de sommeil", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                BlocBuilder<PlayerCubit, PlayerState>(
                  builder: (context, state) {
                    return Column(
                      children: [
                        if (state.isSleepTimerActive && state.sleepTimerRemaining != null) ...[
                          Text(
                            "S'arrête dans : ${_formatDuration(state.sleepTimerRemaining!)}",
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppDimensions.spacingMd),
                          ListTile(
                            leading: const Icon(Icons.timer_off_outlined),
                            title: const Text("Désactiver le minuteur"),
                            onTap: () {
                              context.read<PlayerCubit>().cancelSleepTimer();
                              Navigator.pop(context);
                            },
                          ),
                          const Divider(),
                        ],
                        _buildTimerOption(context, 15),
                        _buildTimerOption(context, 30),
                        _buildTimerOption(context, 45),
                        _buildTimerOption(context, 60),
                      ],
                    );
                  }
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimerOption(BuildContext context, int minutes) {
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: Text("$minutes minutes"),
      onTap: () {
        context.read<PlayerCubit>().startSleepTimer(Duration(minutes: minutes));
        Navigator.pop(context);
      },
    );
  }

  void _showAddToPlaylistSheet(BuildContext parentContext, TrackModel track) {
    final libraryCubit = parentContext.read<LibraryCubit>();
    showModalBottomSheet(
      context: parentContext,
      builder: (sheetContext) {
        return BlocProvider.value(
          value: libraryCubit,
          child: BlocBuilder<LibraryCubit, LibraryState>(
            builder: (ctx, state) {
              if (state is LibraryLoaded) {
                final playlists = state.playlists;
                if (playlists.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(AppDimensions.spacingLg),
                    child: Text("Aucune playlist disponible."),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(AppDimensions.spacingMd),
                      child: Text("Ajouter à la playlist", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = playlists[index];
                          return ListTile(
                            leading: const Icon(Icons.queue_music),
                            title: Text(playlist.name),
                            subtitle: Text("${playlist.tracksCount} morceaux"),
                            onTap: () {
                              libraryCubit.addTrackToPlaylist(playlist.id, track);
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final dismissThreshold = screenHeight * 0.2;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! > 0) {
          setState(() { _dragOffsetY += details.primaryDelta!; });
        }
      },
      onVerticalDragEnd: (details) {
        if (_dragOffsetY > dismissThreshold) {
          Navigator.of(context).pop();
        } else {
          setState(() { _dragOffsetY = 0.0; });
        }
      },
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        transform: Matrix4.translationValues(0, _dragOffsetY, 0),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity((1 - (_dragOffsetY / screenHeight)).clamp(0.2, 1.0)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXxl)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXxl)),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: BlocListener<PlayerCubit, PlayerState>(
              listenWhen: (prev, cur) => prev.currentIndex != cur.currentIndex,
              listener: (context, state) {
                if (_pageController != null && _pageController!.hasClients) {
                  if (_pageController!.page?.round() != state.currentIndex) {
                    _pageController!.animateToPage(
                      state.currentIndex,
                      duration: AppAnimations.normal,
                      curve: AppAnimations.standard,
                    );
                  }
                }
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
                  // Arrière-plan dégradé
                  AnimatedContainer(
                    duration: AppAnimations.verySlow,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _dominantColor?.withOpacity(0.6) ?? colorScheme.primary.withOpacity(0.3),
                          _dominantColor?.withOpacity(0.1) ?? colorScheme.surface,
                          colorScheme.surface,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),

                  // Contenu
                  SafeArea(
                    child: BlocBuilder<PlayerCubit, PlayerState>(
                      builder: (context, state) {
                        if (!state.hasTrack) {
                          return const Center(child: Text("Aucun morceau"));
                        }

                        final track = state.currentTrack!;
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

                        return Column(
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(AppDimensions.spacingMd, AppDimensions.spacingLg, AppDimensions.spacingMd, AppDimensions.spacingSm),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  SonoritizIconButton(
                                    icon: Icons.keyboard_arrow_down_rounded,
                                    tooltip: "Fermer",
                                    color: colorScheme.onSurface,
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  Text(
                                    "En cours de lecture",
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  Row(
                                    children: [
                                      BlocBuilder<LibraryCubit, LibraryState>(
                                        builder: (context, libraryState) {
                                          final isFav = context.read<LibraryCubit>().isFavorite(track.id);
                                          return SonoritizIconButton(
                                            icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            tooltip: isFav ? "Retirer des favoris" : "Ajouter aux favoris",
                                            color: isFav ? colorScheme.primary : colorScheme.onSurface,
                                            onPressed: () {
                                              if (isFav) {
                                                context.read<LibraryCubit>().removeFavorite(track.id);
                                              } else {
                                                context.read<LibraryCubit>().addFavorite(track);
                                              }
                                            },
                                          );
                                        },
                                      ),
                                      SonoritizIconButton(
                                        icon: Icons.more_vert_rounded,
                                        tooltip: "Options",
                                        color: colorScheme.onSurface,
                                        onPressed: () => _showMoreOptionsBottomSheet(context, track),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: AppAnimations.normal).slideY(begin: -0.2, end: 0),

                            const SizedBox(height: AppDimensions.spacingMd),

                            // Artwork Carousel
                            PlayerArtworkCarousel(
                              pageController: _pageController!,
                              coverSize: coverSize,
                              dominantColor: _dominantColor,
                              isVideoMode: _isVideoMode,
                              isVideoLoading: _isVideoLoading,
                              videoController: _videoController,
                              position: position,
                              duration: duration,
                            ).animate().fadeIn(duration: AppAnimations.slow),

                            const SizedBox(height: AppDimensions.spacingLg),

                            // Track Info
                            PlayerTrackInfo(
                              title: track.title,
                              artistName: track.artistName,
                            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

                            const SizedBox(height: AppDimensions.spacingXl),

                            // Progress Bar
                            PlayerProgressBar(
                              position: position,
                              duration: duration,
                              onSeek: (newPosition) {
                                if (_isVideoMode && _videoController != null) {
                                  _videoController!.seekTo(newPosition);
                                } else {
                                  context.read<PlayerCubit>().seek(newPosition);
                                }
                              },
                            ).animate().fadeIn(delay: 300.ms),

                            const Spacer(),

                            // Primary Controls
                            PlayerPrimaryControls(
                              isPlaying: isPlaying,
                              isShuffleModeEnabled: state.isShuffleModeEnabled,
                              loopMode: state.loopMode,
                              onPlayPause: () {
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
                              onPrevious: () => context.read<PlayerCubit>().playPrevious(),
                              onNext: () => context.read<PlayerCubit>().playNext(),
                              onShuffle: () => context.read<PlayerCubit>().toggleShuffle(),
                              onRepeat: () => context.read<PlayerCubit>().toggleRepeat(),
                            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

                            const Spacer(),

                            // Secondary Controls
                            PlayerSecondaryControls(
                              currentTrack: track,
                              onQueueTapped: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<PlayerCubit>(),
                                    child: const QueueBottomSheet(),
                                  ),
                                );
                              },
                              onLyricsTapped: () {
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
                              onDownloadTapped: () {},
                            ).animate().fadeIn(delay: 500.ms),

                            const SizedBox(height: AppDimensions.spacingLg),
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
